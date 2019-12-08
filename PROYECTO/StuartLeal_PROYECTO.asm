;; ===========================================================================
;; Autor: Stuart Leal Quesada | B53777
;; Fecha: 9 de diciembre de 2019
;; Version: 1.0
;; Explicación:
;;
;;  - Este programa implementa la solución de software llamada RADAR 623.
;;  Este radar, se encarga de medir la velocidad de un vehículo, y indicarle
;;  al conductor del vehículo, su velocidad, el límite de velocidad, y 
;;  alertarlo si su velocidad exede este límite.
;;
;;  - Hay tres modos de funcionamiento:
;;      + MODO LIBRE:    En este modo el sistema está ocioso, y no se realiza
;;                       ningún cálculo.
;;      
;;                       Código: PH7-PH6 = ON-OFF
;;
;;      + MODO MEDICIÓN: En este modo el sistema está funcionando, y mide
;;                       la velocidad, basado en el tiempo que le toma a un
;;                       vehículo pasar entre dos sensores, conectados en PH3
;;                       y PH0.
;;                       La velocidad es desplegada utilizando los displays de
;;                       siete segmentos de la tarjeta Dragon 12.
;;
;;                       Código: PH7-PH6 = ON-ON
;;
;;      + MODO CONFIG:   En este modo, el sistema permite la configuración de
;;                       la velocidad máxima. Se utiliza el teclado matricial
;;                       para meter datos, y las teclas de Enter y Borrar para
;;                       manipular la entrada de datos.
;;
;;                       Código: PH7-PH6 = OFF-OFF
;;
;;  - Listado de las subrutinas (en orden):
;;  - Subrutinas de atención de interrupciones
;;      + ATD0_ISR
;;      + TCNT_ISR
;;      + CALCULAR
;;      + RTI_ISR
;;      + OC4_ISR
;;  - Subrutinas generales
;;      + MUX_TECLADO
;;      + TAREA_TECLADO
;;      + FORMAR_ARRAY
;;      + MODO_MEDICION
;;      + PANT_CTRL
;;      + MODO_CONFIG
;;      + MODO_LIBRE
;;      + BCD_BIN
;;      + CONV_BIN_BCD
;;      + BIN_BCD
;;      + BCD_7SEG
;;      + DELAY
;;      + SEND
;;      + LCD
;;      + CARGAR_LCD
;;      + PATRON_LEDS
;;  
;; ===========================================================================

#include registers.inc

;; ===========================================================================
;; ==================== DECLARACION DE ESTRUCTURAS DE DATOS ==================
;; ===========================================================================

                        org $1000

EOM:                    equ $0
N:                      equ 100
MAX_BRILLO:             equ 20
;;                      Banderas generales
;;                      => Se manejan con Banderas+1,[$01,$02,$04,$08,$10,..]
;;                      Banderas.0 : TCL_LISTA      $01
;;                      Banderas.1 : TCL_LEIDA      $02
;;                      Banderas.2 : ARRAY_OK       $04
;;                      Banderas.3 : PANT_FLAG      $08
;;                      Banderas.4 : ALERTA         $10
;;                      Banderas.5 : STATE_CHANGED  $20
;;                      Banderas.6 : PH6_THEN       $40
;;                      Banderas.7 : PH7_THEN       $80
;;                      => Se manejan con Banderas,[$01,$02,$04,$08,$10,..]
;;                      Banderas.8 : SEND_CMD (0) or SEND_DATA (1)
;;                      Banderas.9 : CALC_TICKS     $02
;;                      Banderas.10 : OUT_RANGE     $04
;;                      Banderas.11 : --            $08
;;                      Banderas.12 : --            $10
;;                      Banderas.13 : --            $20
;;                      Banderas.14 : --            $40
;;                      Banderas.15 : PH3_FIRED     $80
Banderas:               ds 2
;;                      Variables para MODO_CONFIG
V_LIM:                  ds 1
;;                      Variables para TAREA_TECLADO
MAX_TCL:                db 2        ;; Set de valor MAX_TCL
Tecla:                  ds 1
Tecla_in:               ds 1
Cont_reb:               ds 1
Cont_TCL:               ds 1
Patron:                 ds 1
Num_Array:              ds 6
;;                      Variables para ATD_ISR
BRILLO:                 ds 1
POT:                    ds 1
;;                      Variables para PANT_CONTRL
TICK_EN:                ds 2
TICK_DIS:               ds 2
;;                      Variables para CALCULAR
VELOC:                  ds 1
;;                      Variables para TCNT_ISR
TICK_VEL:               ds 1
;;                      Variables para CONV_BIN_BCD
BIN1:                   ds 1
BIN2:                   ds 1
BCD1:                   ds 1
BCD2:                   ds 1
;;                      Variables para BIN_BCD
BCD_L:                  ds 1
BCD_H:                  ds 1      
;;                      Variables para BCD_7SEG  
DISP1:                  ds 1
DISP2:                  ds 1
DISP3:                  ds 1
DISP4:                  ds 1
;;                      Variables para PATRON_LEDS
LEDS:                   ds 1
;;                      Variables para OC4_ISR
CONT_DIG:               ds 1
CONT_TICKS:             ds 1
DT:                     ds 1
CONT_7SEG:              ds 2                  
CONT_200:               ds 2
;;                      Variables para Subrutinas LCD                  
Cont_Delay:             ds 1
D2ms:                   db 100
D260us:                 db 13
D40us:                  db 2
Clear_LCD:              db $01
ADD_L1:                 db $80
ADD_L2:                 db $C0
;;                      Tablas
Teclas:                 db $01,$02,$03,$04,$05,$06,$07,$08,$09,$0B,$0,$0E

SEGMENT:                db $3F,$06,$5B,$4F,$66,$6D,$7D,$07,$7F,$6F,$40,$00

iniDISP:                db $04,$28,$28,$06,$0C

iniMensajes:
;;                      Mensajes de configuración
CONFIG_L1:              fcc '  MODO CONFIG'
                        db EOM

CONFIG_L2:              fcc ' VELOC. LIMITE'                        
                        db EOM

;;                      Mensajes de medición                        

MED_L1:                 fcc ' MODO MEDICION'                        
                        db EOM

MED_ESP_L2:             fcc '  ESPERANDO...'
                        db EOM

MED_VEL_L2:             fcc 'SU VEL. VEL.LIM'
                        db EOM

MED_CAL_L2:             fcc '  CALCULANDO...'
                        db EOM

;;                      Mensajes de modo libre                        

MODO_LIB_L1:            fcc '  RADAR   623'                        
                        db EOM

MODO_LIB_L2:            fcc '  MODO LIBRE'      
                        db EOM                  

;; ===========================================================================
;; ==================== DECLARACION DE INTERRUPCIONES ========================
;; ===========================================================================

                        org $3E70
                        dw RTI_ISR

                        org $3E4C
                        dw CALCULAR

                        org $3E66
                        dw OC4_ISR

                        org $3E52
                        dw ATD0_ISR

                        org $3E5E
                        dw TCNT_ISR

;; ===========================================================================
;; ==================== RUTINA DE INICIALIZACIÓN =============================
;; ===========================================================================

                        org $2000
                        lds #$3bff                        

                        ;; CONFIGURACION DE ATD0
                        ldab 200
                        movb #$C2 ATD0CTL2

MN_wait_10us            dbne b,MN_wait_10us

MN_After_10us           movb #$30 ATD0CTL3
                        movb #$BF ATD0CTL4

                        ;; para OC4
                        movb #$90 TSCR1     ;; Habilitar TEN y FFCA
                        movb #$03 TSCR2     ;; Habilitar PRS = 8
                        movb #$10 TIOS      ;; Habiliar OC 4
                        movb #$10 TIE       ;; Empezar oc

                        ;; para teclado matricial                        
                        movb #$F0 DDRA      ;; 4msb como entradas de PORTA
                        bset PUCR,$01       ;; Pull-up en PORTA

                        ;; para RTI
                        movb #$40 RTICTL    ;; t = 1.024 ms
                        bset CRGINT $80     ;; RTI enable

                        ;; para DDRK -> LCD
                        movb #$FF DDRK             

                        ;; Configuración de LEDS
                        ;; habilitar puerto b como salidas -> LEDS
                        movb #$FF DDRB
                        ;; habilitar puerto j (tierra de leds)     
                        bset DDRJ,$02
                        ;; habilitar puerto p (tierras de disp)
                        movb #$0F DDRP

                        ;; habilitar H como entrada, flanco decreciente en 0,3
                        ;; Botones de PH
                        clr DDRH
                        movb #$F6 PPSH
                        movb #$FF PIFH
                        clr PIEH        ;; Deshabilitar interrupciones                        

                        ;; Habilitar interrupciones, y realizar primer
                        ;; calculo para OC4 y ATD
                        cli                 ;; I = 0

                        ldd TCNT            ;; Primer oc
                        addd #60
                        std TC4                               

;; ===========================================================================
;; ==================== INICIALIZACIÓN DE VARIABLES ==========================
;; ===========================================================================

                        ;; Limpiar contadores de OC4
                        clr CONT_DIG
                        clr CONT_TICKS
                        movw #5000 CONT_7SEG
                        movw #10000 CONT_200

                        ;; Limpiar V_LIM y VELOC
                        clr V_LIM
                        clr VELOC                        

                        ;; Limpiar TODAS las banderas... Luego se 
                        ;; configuran las que son necesarias
                        ldx #0
                        stx Banderas

                        ;; Limpiar variables para el teclado matricial
                        movb #$FF Tecla
                        movb #$FF Tecla_in
                        clr Cont_TCL
                        movb #10 Cont_reb

                        ;; Imprimir mensaje de config primera vez
                        ldx #CONFIG_L1
                        ldy #CONFIG_L2
                        jsr LCD

                        ;; Limpiar todos los LEDS
                        movb #$BB,BIN1
                        movb #$BB,BIN2
                        ;; set leds en config
                        movb #$01,LEDS

;; ===========================================================================
;; ==================== PROGRAMA PRINCIPAL ===================================
;; ===========================================================================

MN2                     ;; Traer sólo los bits de estado de PTH y Banderas+1
                        ldaa Banderas+1
                        anda #$C0
                        ldab PTIH
                        andb #$C0

                        ;; Verificar si V_LIM = 0, en cuyo caso ir a CFG
                        tst V_LIM
                        beq MN2_cfg_mode

                        ;; Verificar si R2 != $40
                        cmpb #$40
                        bne MN2_chk_r1_eq_r2

                        ;; Caso R2 = $40 -> Estado indefinido
                        tfr a,b

MN2_chk_r1_eq_r2        cba
                        beq MN2_clr_state_chgd

                        ;; Estado diferente al anterior!
                        bset Banderas+1,$20

                        ;; Guardar nuevo estado en Banderas
                        ;; y dejar R2 nuevamente con sólo el estado
                        bclr Banderas+1,$C0
                        addb Banderas+1
                        stab Banderas+1
                        andb #$C0

                        bra MN2_chk_med_mode                        

MN2_clr_state_chgd      bclr Banderas+1,$20

MN2_chk_med_mode        ;; Caso donde V_LIM != 0
                        cmpb #$C0
                        beq MN2_med_mode

                        ;; Caso donde mode != medicion
                        brclr Banderas+1,$20,MN2_chk_mode

                        ;; Caso donde primera vez que modo != medicion
                        bclr TSCR2,$80
                        clr PIEH

                        clr VELOC
                        movb #$BB,BIN1
                        movb #$BB,BIN2

                        bclr Banderas,$80 ;; PH3_FIRED
                        bset Banderas,$02 ;; CALC_TICKS
                        bclr Banderas+1,$10 ;; ALERTA
                        bclr Banderas+1,$08 ;; PANT_FLAG

                        ;; Verificar si modo = CONFIG | LIBRE
MN2_chk_mode            cmpb #$00
                        beq MN2_cfg_mode

                        ;; Caso donde mode TIENE que ser MODO_LIBRE
                        jsr MODO_LIBRE
                        bra MN2

MN2_cfg_mode            ;; Caso donde estamos en MODO_CONFIG
                        jsr MODO_CONFIG
                        bra MN2                        

MN2_med_mode            ;; Caso donde estamos en MODO_MEDICION
                        jsr MODO_MEDICION
                        bra MN2                        

fin                     bra *

;; ===========================================================================
;; ==================== SUBRUTINAS DE INTERRUPCIONES =========================
;; ===========================================================================

;; ==================== Subrutina ATD0_ISR ===================================
;; Descripción: Subrutina de interrupcion para ATD0.
;; 
;;  - Se calcula el promedio de seis mediciones del PAD7, y se encuentra un
;;  valor para el brillo a partir de la ecuación: BRILLO = (20 x POT) / 255
;; 
;;  PARAMETROS DE ENTRADA: ninguno
;;  PARAMETROS DE SALIDA: 
;;      - POT: Variable tipo byte, sin signo donde se almacena el valor
;;             del POT, como un valor de 0 a 255.
;;
;;      - BRILLO: Variable tipo byte, con un valor de 0 a 20. Define el
;;                brillo de la pantalla.             
;;

ATD0_ISR                 ;; sumar todos los datos
                        ldd ADR00H
                        addd ADR01H
                        addd ADR02H
                        addd ADR03H
                        addd ADR04H
                        addd ADR05H

                        ;; promediar POT
                        ldx #6
                        idiv
                        tfr x,a
                        staa POT

                        ;; calcular BRILLO
                        ldab #20
                        mul
                        ldx #255
                        idiv
                        tfr x,a
                        staa BRILLO

                        rti

;; ==================== Subrutina TCNT_ISR ===================================
;; Descripción: Subrutina de interrupción para el Overflow de TCNT.
;; 
;;  - Con esta subrutina, la subrutina CALCULO realiza los cálculos de 
;;  velocidad, mediante la variable TICK_VEL. Esta variable se incremente
;;  con cada interrupción, por tanto, dado la cadencia de esta subrutina, 
;;  se puede terminar el tiempo entre S1 y S2, y calcular la velocidad
;;  del vehículo.
;;
;;  Además, se realiza el conteo de tiempo para encender y apagar el DISPLAY 
;;  con el mensaje adecuado, de acuerdo a la posición del vehículo, utilizando 
;;  las variables TICK_EN y TICK_DIS.
;;
;;  Consideraciones: Como TICK_DIS > TICK_EN, entonces se asume que SIEMPRE
;;  que TICK_EN != 0, TICK_DIS también va a ser != 0. 
;; 
;;  PARAMETROS DE ENTRADA: ninguno
;;  PARAMETROS DE SALIDA: 
;;      - PANT_FLAG: Bit 3 del registro de Banderas.
;;                   Si la bandera está en uno, quiere decir que se debe
;;                   encender el DISPLAY para indicar la velocidad al usuario.
;;                   Si la bandera está en cero, se debe apagar el display,
;;                   pues se calcula que el usuario ya pasó por el letrero.
;;                        

TCNT_ISR                ;; incrementar velocidad, mientras sea menor a 255
                        ldaa TICK_VEL
                        cmpa #255
                        beq TCNT_check_en

                        inc TICK_VEL

                        ;; CORREGIR: TICK_EN y TICK_DIS son words
TCNT_check_en           ldx TICK_EN
                        cpx #0
                        beq TCNT_en_zero

                        ;; si TICK_EN != 0, de fijo TICK_DIS tampoco
                        dex
                        stx TICK_EN

                        ldx TICK_DIS
                        dex
                        stx TICK_DIS

                        bra TCNT_retornar

TCNT_en_zero            ldx TICK_DIS
                        cpx #0
                        beq TCNT_check_pflg_off

                        dex
                        stx TICK_DIS

                        ;; Sólo encender PANT_FLAG si es 0
                        brset Banderas+1,$08,TCNT_retornar
                        bset Banderas+1,$08
                        bra TCNT_retornar 

                        ;; Sólo apagar PANT_FLAG si es 1
TCNT_check_pflg_off     brclr Banderas+1,$08,TCNT_retornar
                        bclr Banderas+1,$08

                        ;; borrar bandera de interrupción
TCNT_retornar           ldd TCNT                                

                        rti

;; ==================== Subrutina CALCULAR ===================================
;; Descripción: Subrutina de interrupción para puerto H.
;; 
;;  - En esta subrutina se realiza el cálculo de velocidad, utilizando un
;;  contador que es incrementado periódicamente con la subrutina TCNT_ISR. 
;; 
;;  Formula para el cálculo:
;;      velocidad_kmh = (16875 * 25) / (TICK_VEL * 64)
;;
;;      -> Primero se hace la múltiplicación del denominador, y el resultado
;;      queda en X. Luego el numerador, y el resultado queda en Y:D. 
;;      Y por último, se realiza la división, y el resultado queda en Y.
;;
;;  - Sólo se escucha a PIFH 0 si previamente se ha estripado PIFH 3.
;;  Para esto se usa una bandera en el bit 15 de Banderas. En 0 PIFH 3
;;  no se estripó, y en 1, ya se estripó anteriomente. Siempre los pulsos
;;  de PH3 se espera que vengan acompañados de un pulso en PIFH 0.
;; 
;;  PARAMETROS DE ENTRADA: ninguno
;;  PARAMETROS DE SALIDA: 
;;      - VELOC:     Esta interrupción calcula la velocidad en KM/H y
;;                   guarda el resultado en VELOC.
;; 

CALCULAR                tst Cont_reb
                        bne Calc_rst_and_return

                        brset PIFH,$08,Calc_rst_tick_vel
                        brset PIFH,$01,Calc_veloc

                        ;; si no es ni PH0 ni PH3, borrar todas
                        ;; y retornar
Calc_rst_and_return     movb #$FF PIFH
                        bra Calc_retornar

Calc_rst_tick_vel       ;; caso de PH3
                        ;; Verificar si PH3_FIRED ya fué activada
                        brset Banderas,$80,Calc_rst_ph3

                        ;; Caso donde es la primera vez, activar PH3_FIRED
                        clr TICK_VEL
                        bset Banderas,$80

                        ;; Ya se había activado PH3_FIRED previamente
Calc_rst_ph3            bset PIFH,$08

                        bra Calc_set_cntr

Calc_veloc              ;; caso de PH0
                        brclr Banderas,$80,Calc_reset_ph0

                        ;; Deshabilitar interrupciones para el puerto H
                        clr PIEH
                        ;; Habilitar interrupciones (OC4) para DELAY
                        cli

                        ;; Caso donde PH3_FIRED = 1 -> Vehículo detectado
                        ;; Cambiar mensajes de LCD de medicion
                        ldx #MED_L1
                        ldy #MED_CAL_L2
                        jsr LCD

                        ;; Deshabilitar interrupciones nuevamente
                        sei
                        ;; Habilitar interrupciones para el puerto H
                        movb #$09 PIEH

                        ;; calcular denominador
                        ldaa TICK_VEL
                        ldab #64
                        mul
                        tfr d,x

                        ;; calcular numerador
                        ldd #25
                        ldy #16875
                        emul

                        ;; realizar división
                        ediv

                        ;; verificar si resultado > 255
                        cpy #255
                        bhi Calc_set_max_veloc

                        ;; caso veloc < 255, guardar como está
                        tfr y,a
                        staa VELOC

                        bra Calc_reset_bandera

Calc_set_max_veloc      ;; caso veloc > 255, guardar tope
                        movb #255 VELOC

Calc_reset_bandera      bclr Banderas,$80

Calc_reset_ph0          bset PIFH,$01

                        ;; la idea, es que después de 40ms, ya no va a haber
                        ;; rebotes, entonces esta interrupción no se va a dar

                        ;; NOTA Usar 40ms no afecta, pues la máxima velocidad
                        ;; (99km/h) se alcanza cuando se duran 1.44 seg
                        ;; entre PH3 y PH0.
Calc_set_cntr           movb #40 Cont_reb                                                 

Calc_retornar           rti

;; ==================== Subrutina RTI_ISR ====================================
;; Descripción: Subrutina para decrementar contadores usados para suprimir
;;              rebotes.
;;
;;  - Si se quiere suprimir rebotes, se carga un valor en Cont_reb y esta
;;  subrutina se encarga de decrementar el contador cada 1ms.
;; 
;;  PARAMETROS DE ENTRADA: 
;;      - Cont_reb: Variable tipo byte en donde se guarda el multiplo de 1ms
;;                  a decrementas                    
;;  PARAMETROS DE SALIDA: ninguno

RTI_ISR                 bset CRGFLG,$80    ;; limpiar bander int

                        tst Cont_reb
                        beq RTI_retornar

                        dec Cont_reb

RTI_retornar            rti

;; ==================== Subrutina OC4_ISR ====================================
;; Descripción: Subrutina de interrupción, utilizada para controlar LEDS,
;;              y conversión analógica digital.
;;
;;  - Con el contador CONT_7SEG, se controla que cada 100ms se haga la
;;  conversión de BIN hasta DISP.
;;  - Con el contador CONT_200, se controla que cada 200ms se realiza un ciclo
;;  de conversión analógica digital, y que se ejecutra la subrutina de 
;;  PATRON_LEDS.
;;  - Con el contador CONT_TICKS y CONT_DIG, se realiza la multiplexación de
;;  de la pantalla, y el cálculo del DT, utilizando la variable BRILLO,
;;  cada vez que CONT_TICKS = N (Hay un cambio de dígito).
;; 
;;  PARAMETROS DE ENTRADA: ninguno                    
;;  PARAMETROS DE SALIDA: 
;;      - Cont_Delay: Se utiliza en la subrutina DELAY, para implementar un
;;                    delay bloqueando. La subrutina lee el valor de este
;;                    contador para determinar si debe continuar o seguir
;;                    esperando.
;;

;;                      -> Inicia primera página ==============================
                        ;; Recalcular TC4
OC4_ISR                 ldd TCNT
                        addd #60
                        std TC4

                        ;; Verificar si Cont_Delay = 0
                        tst Cont_Delay
                        beq OC4_MUX

                        dec Cont_Delay

                        ;; Verificar si CONT_TICKS = 100
OC4_MUX                 ldaa CONT_TICKS
                        cmpa #N
                        beq OC4_inc_cont_dig

                        ;; Caso donde R1 != 100
                        inc CONT_TICKS
                        bra OC4_tst_ticks

                        ;; Caso R1 = 100 
OC4_inc_cont_dig        clr CONT_TICKS
                        inc CONT_DIG

                        ;; Calcular valor de K, donde DT = N - K
                        ldaa #MAX_BRILLO
                        suba BRILLO
                        ldab #N
                        mul
                        ldx #MAX_BRILLO
                        idiv 
                        tfr x,b

                        ;; Calcular nuevo valor de DT. K se encuentra en R2
                        ldaa #N
                        sba
                        staa DT

                        ;; Verificar si CONT_DIG = 5
                        ldaa CONT_DIG
                        cmpa #5
                        bne OC4_tst_ticks

                        clr CONT_DIG

                        ;; Verificar si CONT_TICKS = 0
OC4_tst_ticks           tst CONT_TICKS
                        beq OC4_P2A

                        ;; Verificar si CONT_TICKS = DT
OC4_P2B                 ldaa CONT_TICKS
                        cmpa DT
                        bne OC4_P2C

                        bset PTJ,$02
                        movb #$0F PTP

                        bra OC4_P2C

;;                      -> Inicia segunda página ==============================
OC4_P2A                 ldaa CONT_DIG
                        
                        ;; Verificar cuál caso de CONT_DIG estamos
                        cmpa #0
                        beq OC4_ld_0

                        cmpa #1
                        beq OC4_ld_1

                        cmpa #2
                        beq OC4_ld_2

                        cmpa #3
                        beq OC4_ld_3

                        cmpa #4
                        beq OC4_ld_4

                        ;; Caso de ninguna de las anteriores, regresar
                        bra OC4_P2B

                        ;; Inician los posibles casos
OC4_ld_0                movb #$0E PTP
                        bset PTJ,$02
                        movb DISP1 PORTB
                        bra OC4_P2B

OC4_ld_1                movb #$0D PTP
                        movb DISP2 PORTB
                        bra OC4_P2B

OC4_ld_2                movb #$0B PTP
                        movb DISP3 PORTB 
                        bra OC4_P2B

OC4_ld_3                movb #$07 PTP 
                        movb DISP4 PORTB 
                        bra OC4_P2B

OC4_ld_4                movb #$0F PTP
                        bclr PTJ,$02
                        movb LEDS PORTB 
                        bra OC4_P2B                                                                        

;;                      -> Inicia tercera página ==============================
                        ;; Decrementar CONT_7SEG
OC4_P2C                 ldy CONT_7SEG
                        dey
                        sty CONT_7SEG

                        ;; Verificar si CONT_7SEG es distinto de 0
                        cpy #0
                        bne OC4_CONT_200
 
                        ;; Caso donde CONT_7SEG = 0
                        jsr CONV_BIN_BCD
                        jsr BCD_7SEG
                        movw #5000 CONT_7SEG

OC4_CONT_200            ;; Decrementar CONT_200
                        ldy CONT_200
                        dey
                        sty CONT_200

                        ;; Verificar si CONT_200 es distinto de 0
                        cpy #0
                        bne OC4_Retornar

                        ;; Caso donde CONT_200 = 0
                        movb #$87 ATD0CTL5
                        jsr PATRON_LEDS
                        movw #10000 CONT_200

OC4_Retornar            rti

;; ===========================================================================
;; ==================== SUBRUTINAS GENERALES =================================
;; ===========================================================================

;; ==================== Subrutina MUX_TECLADO ================================
;; Descripción: Subrutina utilizada para encontrar la tecla presionada
;;              actualmente.
;; 
;;  - En el puerto A, se encuentra conectado la matriz de botones pulsadores.
;;    Esta subrutina, realiza la multiplexación de los botones, cargando
;;    cuatro patrones específicos en la parte Alta de A: 7,D,B y E.
;;    Luego, lee la parte baja del puerto A para determinar cuál tecla está
;;    siendo presionada.
;; 
;;  PARAMETROS DE ENTRADA: ninguno
;;  PARAMETROS DE SALIDA:
;;      - Tecla:    En esta variable se guarda el valor de la tecla encontrada.
;;                  La codificación correspondiente de cuál tecla corresponde
;;                  a cuál variable se encuentra en el array Teclas.            
;; 

MUX_TECLADO             clr Patron

MX_ld_patron            ldaa Patron
                        cmpa #4
                        beq MX_ret_ff

                        cmpa #3
                        beq Mx_7F

                        cmpa #2
                        beq Mx_BF
                        
                        cmpa #1
                        beq Mx_DF

                        movb #$EF PORTA
                        bra Mx_COMP                                                

Mx_7F                   movb #$7F PORTA
                        bra Mx_COMP

Mx_DF                   movb #$DF PORTA
                        bra Mx_COMP

Mx_BF                   movb #$BF PORTA                                                                        

                        ;; Los nops son para dar tiempo entre cuando se
                        ;; escribe la parte alta, y cuando se lee la parte
                        ;; baja. Se encontraron errores en donde la lectura
                        ;; de la parte baja arrojaba basura.
Mx_COMP                 nop
                        nop
                        nop 
                        nop
                        nop 
                        nop
                        nop 
                        nop
                        nop 

                        brclr PORTA,$01,MX_col0
                        brclr PORTA,$02,MX_col1
                        brclr PORTA,$04,MX_col2

                        inc Patron
                        bra MX_ld_patron

MX_col0                 ldy #$0000
                        bra MX_get_tecla                        

MX_col1                 ldy #$0001
                        bra MX_get_tecla    
                        
MX_col2                 ldy #$0002

MX_get_tecla            ldab #03
                        ldaa Patron
                        mul
                        aby             ;; la mul da entre 0-9. 100pre en B
                        tfr y,a
                        ldy #Teclas
                        movb a,y Tecla

                        bra MX_return

MX_ret_ff               movb #$FF Tecla

MX_return               rts                                                

;; ==================== Subrutina TAREA_TECLADO ==============================
;; Descripción: Subrutina para supresión de rebotes y tecla retenida.
;; 
;;  - Hace uso de la subrutina MUX_TECLADO, quién lee una tecla, y de la 
;;    subrutina FORMAR_ARRAY, que guarda teclas en un arreglo.
;; 
;;  PARAMETROS DE ENTRADA: ninguno
;;  PARAMETROS DE SALIDA: ninguno
;;  ESTADOS INTERNOS:
;;      - BANDERAS: En banderas se escriben dos banderas, en bit 0 se escribe
;;                  TCL_LISTA, y en bit 1 se escribe TCL_LEIDA.
;;      - TECLA_IN: Se usa para guardar la tecla presionada inicialmente,
;;                  para comparar luego de un tiempo determinado (10-20ms) 
;;                  y saber si es la misma o no.

TAREA_TECLADO           tst Cont_reb
                        bne TT_Return

                        jsr MUX_TECLADO

                        ldaa Tecla        ;; (Tecla) = $FF
                        cmpa #$FF 
                        beq TT_Check_antirebote

                        ;; banderas.1 = 1 ?
                        brset Banderas+1,$02,TT_Check_tecla_igual

                        ;; banderas.1 = 0 => TCL NO LEIDA
                        movb Tecla Tecla_in
                        bset Banderas+1,$02 ;; TCL_LEIDA <- 1
                        movb #10 Cont_reb

                        bra TT_Return

TT_Check_antirebote     brset Banderas+1,$01,TT_go_formar_array
                        bra TT_Return

TT_go_formar_array      bclr Banderas+1,$02
                        bclr Banderas+1,$01

                        jsr FORMAR_ARRAY

                        bra TT_Return                     

                        ;; banderas.1 = 1 => TCL LEIDA
TT_Check_tecla_igual    ldaa Tecla_in
                        cmpa Tecla
                        beq TT_Set_tecla_lista

                        movb #$FF Tecla
                        bclr Banderas+1,$02   ;; TCL_LEIDA
                        bclr Banderas+1,$01   ;; TCL_LISTA
                        movb #$FF Tecla_in

                        bra TT_Return

TT_Set_tecla_lista      bset Banderas+1,$01   ;; TCL_LISTA <- 1                                     

TT_Return               rts                    

;; ==================== Subrutina FORMAR_ARRAY =============================== 

FORMAR_ARRAY            ldab Cont_TCL
                        cmpb MAX_TCL
                        beq FA_Check_Last

                        cmpb #0
                        beq FA_Check_First

                        ldaa #$0E
                        cmpa Tecla_in
                        beq FA_Middle_End

                        ldaa #$0B
                        cmpa Tecla_in
                        beq FA_Middle_Erase

                        ldx #Num_Array
                        movb Tecla_in b,x
                        inc Cont_TCL
                        
                        bra FA_Return

FA_Middle_Erase         dec Cont_TCL
                        ldab Cont_TCL
                        ldx #Num_Array
                        movb #$FF b,x

                        bra FA_Return

FA_Middle_End           bset Banderas+1,$04    ;; Array_ok <- 1
                        clr Cont_TCL

                        bra FA_Return

FA_Check_First          ldaa #$0E
                        cmpa Tecla_in
                        beq FA_Return

                        ldaa #$0B
                        cmpa Tecla_in
                        beq FA_Return

                        ldx #Num_Array
                        movb Tecla_in b,x
                        inc Cont_TCL

                        bra FA_Return

FA_Check_Last           ldaa #$0E
                        cmpa Tecla_in
                        beq FA_Last_End

                        ldaa #$0B
                        cmpa Tecla_in
                        beq FA_Last_Erase

                        bra FA_Return

FA_Last_End             clr Cont_TCL
                        bset Banderas+1,$04  ;; Array_ok <- 1

                        bra FA_Return

FA_Last_Erase           dec Cont_TCL
                        ldab Cont_TCL
                        ldx #Num_Array        
                        movb #$FF b,x                                                                                                                

FA_Return               rts

;; ==================== Subrutina MODO_MEDICION ==============================
;; Descripción: Subrutina que atiende el MODO_MEDICION, el modo activo del 
;;              RADAR.
;; 
;;  - Esta subrutina se encarga de manejar el control de los mensajes,
;;  y calculos necesarios para calcular correctamente la velocidad del 
;;  vehíuclo que pasa entre los sensores de S1 y S2.
;;  - Se encarga de llamar a PANT_CTRL una vez que detecta que la velocidad
;;  medida por el radar != 0. PANT_CTRL se sigue ejecutando mientras esa
;;  velocidad sea != 0.
;; 
;;  PARAMETROS DE ENTRADA:
;;      - V_LIM:      Esta subrutina utiliza el valor de V_LIM para determinar
;;                    si tiene que llamar a la subrutina de PANT_CTRL o no.
;;  PARAMETROS DE SALIDA: 
;;      - LEDS:       En esta variable, se configura el LED correspondiente
;;                    que indica que se encuentra en este modo.
;;
;;  ESTADOS INTERNOS:
;;      - Banderas.5: Esta bandera de STATE_CHANGE, es utilizada para verificar
;;                    si es la primera vez que se ejecuta esta subrutina
;;                    después de haber estado en otro modo. En cuyo caso,
;;                    se tiene que habilitar las interrupciones por OVERFLOW
;;                    de TCNT, y las interrupciones de Key Wakeups del puerto
;;                    H para el pin 3 y el pin 0.
;;                                                                               

                        ;; Verificar si esta es la primera vez que entramos
                        ;; a este modo
MODO_MEDICION           brclr Banderas+1,$20,MM_chk_veloc

                        ;; Caso donde es la primera vez que se entra
                        ;; a esta subrutina
                        bset TSCR2,$80      ;; Habilitar int de overflow TCNT
                        movb #$09,PIEH      ;; Habilitar keywakeups PH3 y PH0
                        movb #$02,LEDS      ;; Poner el modo en los LEDS

                        ;; BORRAR los valores de BIN
                        movb #$BB BIN1
                        movb #$BB BIN2

                        ;; Cargar en el LCD los mensajes correspondientes
                        ldx #MED_L1
                        ldy #MED_ESP_L2
                        jsr LCD

                        ;; Cargar CALC_TICKS en 1
                        bset Banderas,$02

                        ;; Verificar si VELOC = 0
MM_chk_veloc            tst VELOC
                        beq MM_retornar

                        ;; Caso donde VELOC != 0
                        jsr PANT_CTRL

                        ;; Caso donde VELOC = 0
MM_retornar             rts

;; ==================== Subrutina PANT_CTRL ==================================
;; Descripción: Subrutina que orquestra la lógica cuando VELOC != 0.
;; 
;;  - Cuando la VELOC calculada es distinta de 0, esta subrutina debe
;;  realizar varias tarea:
;;      + Verificar que VELOC esté dentro de los rangos permitiros (30-99).
;;      + Cuando VELOC está fuera del rango, se debe mostrar '--' en vez
;;      de la velocidad.
;;      + Verificar si VELOC es mayor que V_LIM. En cuyo caso, debe encender
;;      la bandera de ALERTA (Banderas.4) para indicar a PATRON_LEDS que
;;      debe iniciar la secuencia.
;;      + Realizar los cálculos para TICK_EN y TICK_DIS. Estos son la cantidad
;;      de TICKS que se deben contar en TCNT, para que cuando el vehículo
;;      este a 100m de la pantalla, TICK_EN = 0, y además, cuando el vehículo
;;      este debajo de la pantalla, TICKS_DIS = 0.
;;      + Orquestrar la lógica de cambiar los mensajes del LCD, y del display
;;      de 7 segmentos, para que cuando el vehículo esté a 100m de ambos,
;;      se indique la velocidad límite y la velocidad que lleva.
;;      + Orquestrar la lógica de apagar los displays de 7 segmentos cuando
;;      el vehículo está por debajo del display, y además, devolver VELOC = 0.
;;
;;      NOTA: Cuando se encuentra que VELOC != 0, la primera vez se debe
;;      deshabilitar las interrupciones del puerto H para impedir que se
;;      realice otra medición durante la secuencia descrita anteriormente.
;; 
;;  PARAMETROS DE ENTRADA:
;;      - V_LIM:      Esta subrutina utiliza el valor de V_LIM para determinar
;;                    si tiene que llamar a la subrutina de PANT_CTRL o no.
;;  PARAMETROS DE SALIDA: 
;;      - LEDS:       En esta variable, se configura el LED correspondiente
;;                    que indica que se encuentra en este modo.
;;
;;  ESTADOS INTERNOS:
;;      - Banderas.5: Esta bandera de STATE_CHANGE, es utilizada para verificar
;;                    si es la primera vez que se ejecuta esta subrutina
;;                    después de haber estado en otro modo. En cuyo caso,
;;                    se tiene que habilitar las interrupciones por OVERFLOW
;;                    de TCNT, y las interrupciones de Key Wakeups del puerto
;;                    H para el pin 3 y el pin 0.
;; 

PANT_CTRL               ;; Deshabilitar interrupciones en puerto H
                        clr PIEH

                        ;; Verificar si CALC_TICKS = 1
                        brset Banderas,$02,PTC_calc

                        ;; Caso donde CALC_TICKS = 0, ya se hicieron los calc
                        ldaa BIN1

                        ;; Verificar si PANT_FLAG = 1
                        brset Banderas+1,$08,PTC_chk_vel

                        ;; Caso donde PANT_FLAG = 0
                        ;; Verificar si BIN1 tiene V_LIM o no ($BB)
                        cmpa #$BB
                        beq PTC_local_return

                        ;; Caso donde R1 != $BB, PANT_FLAG = 0
                        ;; Acá, previamente el LCD estuvo encendido
                        ;; con el mensaje de la velocidad calculada, y ahora
                        ;; tenemos que apagarlo, y reiniciar el estado
                        ;; a ESPERANDO...

                        ;; Actualizar mensaje
                        ldx #MED_L1
                        ldy #MED_ESP_L2
                        jsr LCD

                        ;; Reiniciar variables
                        movb #$BB BIN1
                        movb #$BB BIN2
                        clr VELOC
                        movb #$09 PIEH
                        bclr Banderas,$04 ;; Borrar bandera de OUT_RANGE
                        bset Banderas,$02 ;; Poner CALC_TICKS = 1
                        bclr Banderas+1,$10 ;; Ponert ALERTA = 0

                        bra PTC_retornar

PTC_chk_vel             ;; Caso donde PANT_FLAG = 1
                        ;; Verificar si BIN1 tiene V_LIM o no ($BB)
                        cmpa #$BB
                        bne PTC_retornar

                        ;; Caso donde R1 = $BB, PANT_FLAG = 1
                        ;; Este es el caso donde HAY que encender el LCD
                        ;; porque el vehículo está a 100m de la pantalla
                        
                        ;; Actualizar mensaje
                        ldx #MED_L1
                        ldy #MED_VEL_L2
                        jsr LCD

                        ;; Verificar si OUT_RANGE = 1
                        brset Banderas,$04,PTC_guiones

                        ;; Caso donde OUT_RANGE = 0, velocidad dentro del rango 
                        ;; Poner V_LIM y VELOC en 7 segmentos
                        movb V_LIM BIN1
                        movb VELOC BIN2

PTC_local_return        bra PTC_retornar

                        ;; Caso donde OUT_RANGE = 1, velocidad está fuera del
                        ;; rango
                        ;; Poner V_LIM y '--' en 7 segmentos
PTC_guiones             movb V_LIM BIN1
                        movb #$AA BIN2

                        bra PTC_retornar

PTC_calc                ;; Caso donde CALC_TICS = 1, no se han hecho calculos
                        ;; Verificar si CALC < 30
                        ldaa VELOC
                        cmpa #30
                        blo PTC_invalid_vel

                        cmpa #99
                        bhi PTC_invalid_vel

                        ;; La velocidad es válida, pero hay que verificar
                        ;; si la velocidad es más alta que el límite, y
                        ;; en dado caso, encender la ALERTA
                        cmpa V_LIM
                        bls PTC_calculate

                        bset Banderas+1,$10 ;; Poner en 1 ALERTA

                        ;; Velocidad válida, pero hay que calcular el valor
                        ;; de TICK_EN, y de TICK_DIS
PTC_calculate           ldaa VELOC
                        tfr a,x
                        ldd #16480        ;; Constante para 100m
                        idiv
                        stx TICK_EN

                        ldaa VELOC
                        tfr a,x
                        ldd #32959        ;; Constante para 200m
                        idiv
                        stx TICK_DIS

                        bra PTC_calc_finish

                        ;; Caso donde VELOC tiene una velocidad inválida
PTC_invalid_vel         bset Banderas,$04   ;; Cargar 1 en OUT_RANGE
                        movw #1 TICK_EN     ;; Cargar 1 en TICK_EN 
                        movw #92 TICK_DIS   ;; Suficiente para que dure 2 seg        

PTC_calc_finish         bclr Banderas,$02   ;; Borrar bandera de CALC_TICKS   

PTC_retornar            rts

;; ==================== Subrutina MODO_CONFIG ================================
;; Descripción: Subrutina que atiende el MODO_CONFIG, donde se configura V_LIM.
;; 
;;  - Mediante el uso del teclado matricial, esta subrutina se encarga de
;;  verificar si el usuario ha ingresado un valor válido o no. En caso de que
;;  la respuesta sea sí, se guarda el valor válido en la variable V_LIM como
;;  una variable en binario.
;; 
;;  PARAMETROS DE ENTRADA: ninguno
;;  PARAMETROS DE SALIDA: 
;;      - V_LIM:      Esta subrutina es la encargada de definir V_LIM, y
;;                    verificar que el valor está en un rango permitido.
;;
;;      - BIN1:       El valor actual de V_LIM se guarda en BIN1 cuando
;;                    el programa se encuentra en MODO_CONFIG, para que el
;;                    usuario lo pueda ver.
;;  ESTADOS INTERNOS:
;;      - Banderas.2: Esta es la bandera de ARRAY_OK, y esta subrutina se
;;                    encarga de modificar esta bandera, para forzar a 
;;                    TAREA_TECLADO a volver a iniciar el proceso de leer
;;                    teclas.
;;      - Banderas.5: Esta bandera indica si el estado cambio. Es decir,
;;                    esta es la primera vez que se entra a MODO_CONFIG.
;;

                        ;; Verificar si esta es la primera vez que se
                        ;; entra a MODO_CONFIG
MODO_CONFIG             brclr Banderas+1,$20,MC_chk_v_lim

                        ;; Primera vez que se entra a MODO_CONFIG
                        ldx #CONFIG_L1
                        ldy #CONFIG_L2

                        ;; Poner LEDS en MODO_CONFIG
                        movb #$01 LEDS

                        ;; Mandar a imprimir el MSG
                        jsr LCD

                        ;; Poner en BIN1 el valor de V_LIM
                        movb V_LIM BIN1

                        ;; Verificar si V_LIM = 0
MC_chk_v_lim            tst V_LIM
                        bne MC_chk_ARRAY_OK

                        ;; Caso donde V_LIM = 0, desplegar valor en DISP
                        movb V_LIM BIN1            

                        ;; Verificar si ARRAY_OK = 0
MC_chk_ARRAY_OK         brclr Banderas+1,$04,MC_jsr_tarea_teclado

                        ;; Caso donde ARRAY_OK != 0
                        ;; Guardar V_LIM en pila temporalmente, para verificar
                        ;; si el nuevo valor de V_LIM está dentro del rango
                        ;; o no. Si no lo está, guardar este valor de nuevo
                        ;; en V_LIM
                        ldab V_LIM
                        pshb

                        ;; Ir a BCD_BIN, y devolver valor temporal a R2
                        jsr BCD_BIN
                        pulb

                        ;; Verificar si V_LIM es menor que 45 km/h
                        ldaa V_LIM
                        cmpa #45
                        blo MC_restore_cprog

                        ;; Verificar si V_LIM es mayor que 90 km/h
MC_check_96             cmpa #90
                        bhi MC_restore_cprog

                        ;; Caso donde V_LIM está dentro del rango aceptado
MC_change_bin1          movb V_LIM BIN1
    	                bra MC_clear_num_array

                        ;; Caso donde V_LIM está fuera del rango. 
                        ;; En este caso, en R2 hay una copia del valor de
                        ;; V_LIM antes de llamar a BIN_BCD, entonces
                        ;; hay que restaurar esta copia
MC_restore_cprog        stab V_LIM

MC_clear_num_array      ;; Borrar: ARRAY_OK <- 0
                        bclr Banderas+1,$04

                        ;; Borrar NUM_ARRAY con FF
                        clra
                        ldab #6             ;; limpiar Num_array
                        ldx #Num_Array

                        ;; Verificar si ya se limpiaron las 6 teclas
MC_Check_CleanFin       cba
                        beq MC_fin

                        ;; Caso donde todavía R1 != R2
                        movb #$FF a,x
                        inca

                        bra MC_Check_CleanFin              

                        ;; Caso donde ARRAY_OK = 0
MC_jsr_tarea_teclado    jsr TAREA_TECLADO                                                                                                         

MC_fin                  rts      

;; ==================== Subrutina MODO_LIBRE =================================
;; Descripción: Subrutina que atiende el MODO_LIBRE del programa.
;; 
;;  - En este modo, el RADAR muestra en el LCD el mensaje correspondiente,
;;  y se mantiene sin realizar cálculos.
;; 
;;  PARAMETROS DE ENTRADA: ninguno
;;  PARAMETROS DE SALIDA: ninguno
;;  ESTADOS INTERNOS:
;;      - Banderas.5: Esta bandera indica si el estado cambio. Es decir,
;;                    esta es la primera vez que se entra a MODO_LIBRE.
;;

MODO_LIBRE              brclr Banderas+1,$20,ML_retornar

                        ;; Caso en donde es la primera vez que se entra
                        ;; en este modo
                        ldx #MODO_LIB_L1
                        ldy #MODO_LIB_L2
                        
                        ;; Poner LEDS en modo correspondiente
                        movb #$04 LEDS

                        ;; Cambiar LCD
                        jsr LCD

ML_retornar             rts                        

;; ==================== Subrutina BCD_BIN ==================================== 

BCD_BIN                 ldx #Num_Array
                        clra
                        clr V_LIM

BCD_B_check_ff          ldab 1,x+

                        cmpb #$FF
                        beq BCD_B_convert

                        cmpa MAX_TCL
                        beq BCD_B_convert

                        inca

                        bra BCD_B_check_ff

BCD_B_convert           ldx #Num_Array

BCD_B_check_unit        cmpa #1
                        beq BCD_B_add_unit

                        deca
                        ldab #10
                        psha
                        mul
                        ldaa 1,x+
                        mul
                        addb V_LIM
                        stab V_LIM
                        pula

                        bra BCD_B_check_unit   

BCD_B_add_unit          ldab 0,x
                        addb V_LIM
                        stab V_LIM

                        rts       

;; ==================== Subrutina CONV_BIN_BCD ===============================                                                                
;; Descripción: Subrutina utilizada para convertir dos números binarios
;;              a dos números en BCD.
;; 
;;  - Esta subrutina utiliza la subrutina BIN_BCD para convertir dos veces
;;  dos números binarios diferentes a BCD. Estos dos números son: BIN1 y BIN2
;;  y son guardados en BCD como BCD1 y BCD2.
;;
;;  - Hay dos casos especiales. Cuando la subrutina encuentra que hay un
;;  $AA o un $BB en alguna de las dos subrutinas, entonces guardará
;;  exactamente el mismo valor en la variable de BCD correspondiente.
;; 
;;  PARAMETROS DE ENTRADA:
;;      - BIN1:     Primer número binario que se desea cambiar a un número
;;                  en BCD. El resultado será guardado en BCD1.
;;      - BIN2:     Segundo número binario que se desea cambiar a un número
;;                  en BCD. El resultado será guardado en BCD2.
;;  PARAMETROS DE SALIDA:
;;      - BCD1:     Posición en memoria donde se guarda el resultado para el
;;                  primer número en BCD.
;;      - BCD2:     Posición en memoria donde se guarda el resultado para el
;;                  segundo número en BCD.        
;; 

                        ;; Verificar si BIN1 = $BB
CONV_BIN_BCD            ldaa BIN1
                        cmpa #$BB
                        bne CBB_cmp_1_a

                        ;; Caso donde BIN1 = $BB
                        movb #$BB BCD1

                        bra CBB_check_bin2

                        ;; Caso donde BIN1 != $BB
                        ;; Verificar si BIN1 = $AA
CBB_cmp_1_a             cmpa #$AA
                        bne CBB_ld_bin_bcd1

                        ;; Caso donde BIN1 = $AA
                        movb #$AA BCD1 

                        bra CBB_check_bin2

CBB_ld_bin_bcd1         ;; Caso donde BIN1 != $AA               
                        jsr BIN_BCD     ;; Recibe por A el valor binario
                        movb BCD_L BCD1

CBB_check_bin2          ;; Verificar sin BIN2 = $BB
                        ldaa BIN2
                        cmpa #$BB
                        bne CBB_cmp_2_a

                        ;; Caso donde BIN2 = $BB
                        movb #$BB BCD2

                        bra CBB_fin

                        ;; Caso donde BIN2 != $BB
                        ;; Verificar si BIN2 = $AA
CBB_cmp_2_a             cmpa #$AA
                        bne CBB_ld_bin_bcd2

                        ;; Caso donde BIN2 = $AA
                        movb #$AA BCD2

                        bra CBB_fin

CBB_ld_bin_bcd2         ;; Caso donde BIN2 != $AA               
                        jsr BIN_BCD     ;; Recibe por A el valor binario
                        movb BCD_L BCD2           

CBB_fin                 rts                        

;; ==================== Subrutina BIN_BCD ====================================
;; Descripción: Subrutina general para convertir un número binario a BCD.
;; 
;;  - El número se pasa por el registro A, y el resultado se retorna por las
;;  variables BCD_L y BCD_H.
;; 
;;  PARAMETROS DE ENTRADA: 
;;      - A: Por medio del registro A se envía el número binario que se desea
;;           convertir a BCD.
;;  PARAMETROS DE SALIDA:
;;      - BCD_H: Guarda, en el nibble inferior, el tercer dígito (centenas)
;;               del número binario.
;;      - BCD_L: Guarda, en el nibbler inferior, las unidades del número
;;               binario. Y en el nibble del medio, guarda las decenas del
;;               número binario.
;;     

BIN_BCD                 ldy #7
                        clr BCD_H
                        clr BCD_L 

BBCD_rotate              ;; Realizar corrimiento de todos los registros
                        lsla
                        rol BCD_L
                        rol BCD_H

                        ;; Apilar el valor de A, y realizar AND con parte baja
                        psha
                        ldaa BCD_L
                        anda #$0F

                        ;; Verificar si A < 5
                        cmpa #5
                        blo BBCD_store_low

                        ;; Caso donde R >= 5
                        adda #3       

                        ;; Caso donde R < 5
BBCD_store_low          tfr a,b

                        ;; AND de A con parte Alta
                        ldaa BCD_L
                        anda #$F0
                        cmpa #$50
                        blo BBCD_add_low

                        ;; Caso donde R1 >= $50
                        adda #$30

                        ;; Caso donde R1 > $50
BBCD_add_low            aba
                        staa BCD_L
                        pula

                        ;; Ir a BBCD_rotate si y != 0
                        dbne y,BBCD_rotate

BBCD_return             lsla
                        rol BCD_L
                        rol BCD_H

                        rts                                                                                            

;; ==================== Subrutina BCD_7SEG ===================================
;; Descripción: Subrutina encargada actualizar los valores de DISPx.
;; 
;;  - Esta subrutina, se encarga de tomar los valores que se encuentran en
;;  en BCD1 y BCD2 y separarlos en dos (nibble superior e inferior). La 
;;  subrutina utiliza el valor de los nibbles como offset en la tabla SEGMENT 
;;  para encontrar el byte que genera el patron correspondiente para cada DISP.
;;
;;  - El resultado se guarda en DISP1 y DISP2 correspondientemente para el 
;;  BCD1, y en DISP3 y DISP4 correspondientemente para el BCD2.
;; 
;;  PARAMETROS DE ENTRADA:
;;      - BCD1:     Posición en memoria donde se guarda el resultado para el
;;                  primer número en BCD.
;;      - BCD2:     Posición en memoria donde se guarda el resultado para el
;;                  segundo número en BCD.        
;;  PARAMETROS DE SALIDA:
;;      - DISP1:    Display correspondiente al nibble superior de BCD2.
;;      - DISP2:    Display correspondiente al nibble inferior de BCD2.
;;      - DISP3:    Display correspondiente al nibble superior de BCD1.
;;      - DISP4:    Display correspondiente al nibble inferior de BCD1.
;;

                        ;; Cargar en R1 el valor de BCD2
                        ;; Cargar en X posición de tabla SEGMENT
BCD_7SEG                ldaa BCD2
                        ldx #SEGMENT

                        ;; Procesar nibble inferior
                        anda #$0F
                        movb a,x DISP2

                        ;; Procesar nibble superior
                        ldaa BCD2
                        lsra 
                        lsra
                        lsra
                        lsra
                        movb a,x DISP1

                        ;; Cargar en R1 el valor de BCD1
                        ldaa BCD1

                        ;; Procesar nibble inferior
                        anda #$0F
                        movb a,x DISP4

                        ;; Procesar nibble superior
                        ldaa BCD1
                        lsra
                        lsra
                        lsra
                        lsra
                        movb a,x DISP3

BCD_7s_return           rts

;; ==================== Subrutina DELAY ====================================== 

DELAY                   tst Cont_Delay
                        beq DE_return

                        bra DELAY

DE_return               rts                               

;; ==================== Subrutina SEND ======================================= 

SEND                    psha
                        anda #$F0
                        lsra
                        lsra
                        staa PORTK

                        brclr Banderas,$01,SE_cmd_h

                        bset PORTK,$01

                        bra SE_cmd_h_en

SE_cmd_h                bclr PORTK,$01

SE_cmd_h_en             bset PORTK,$02
                        movb D260us Cont_Delay

                        jsr DELAY

                        bclr PORTK,$02

                        pula
                        anda #$0F
                        lsla
                        lsla
                        staa PORTK

                        brclr Banderas,$01,SE_cmd_l

                        bset PORTK,$01

                        bra SE_cmd_l_en

SE_cmd_l                bclr PORTK,$01

SE_cmd_l_en             bset PORTK,$02
                        movb D260us Cont_Delay

                        jsr DELAY

                        bclr PORTK,$02

                        rts           

;; ==================== Subrutina LCD ========================================

LCD                     pshx
                        ldab #1

LC_tst_fin              ldaa iniDISP
                        inca

                        cba
                        beq LC_clr

                        ldx #iniDISP
                        ldaa b,x
                        bclr Banderas,$01

                        jsr SEND

                        movb D40us Cont_Delay

                        jsr DELAY

                        incb

                        bra LC_tst_fin

LC_clr                  ldaa Clear_LCD
                        bclr Banderas,$01

                        jsr SEND

                        movb D2ms Cont_Delay

                        pulx

                        jsr DELAY

                        jsr CARGAR_LCD

                        rts      

;; ==================== Subrutina CARGAR_LCD =================================

CARGAR_LCD              ldaa ADD_L1
                        bclr Banderas,$01

                        jsr SEND

                        movb D40us Cont_Delay

                        jsr DELAY

CLCD_ld_l1              ldaa 1,x+

                        cmpa #EOM
                        beq CLDC_l2

                        bset Banderas,$01

                        jsr SEND

                        movb D40us Cont_Delay

                        jsr DELAY

                        bra CLCD_ld_l1

CLDC_l2                 ldaa ADD_L2
                        bclr Banderas,$01

                        jsr SEND

                        movb D40us Cont_Delay

                        jsr DELAY

CLCD_ld_l2              ldaa 1,y+

                        cmpa #EOM
                        beq CLCD_return

                        bset Banderas,$01

                        jsr SEND

                        movb D40us Cont_Delay

                        jsr DELAY

                        bra CLCD_ld_l2

CLCD_return             rts     

;; ==================== Subrutina PATRON_LEDS =================================
;; Descripción: Subrutina para manejar los LEDS de Alerta.
;; 
;;  - Cuando la bandera de ALERTA (bit 5 de Banderas) está en 1, cada vez
;;  que se llame a esta subrutina, barrera los leds del 7 al 3, de izquierda
;;  a derecha. Sin embargo, si ALERTA está en 0, esta subrutina borrará los
;;  LEDS del 7 al 3.
;; 
;;  PARAMETROS DE ENTRADA: ninguno
;;  PARAMETROS DE SALIDA: ninguno
;;

PATRON_LEDS             brclr Banderas+1,$10,PT_LEDS_clr

                        ;; Verificar si LEDS > 7
                        ldaa LEDS
                        cmpa #7
                        bhi PT_LEDS_shift

                        bset LEDS,$80
                        bra PT_LEDS_retornar

PT_LEDS_shift           ;; Guardar en A la parte baja de LEDS
                        anda #$07
                        
                        ;; Shift a la derecha de LEDS, y limpiar parte baja
                        lsr LEDS
                        bclr LEDS,$07

                        ;; Sumar LEDS con la parte baja de LEDS anteriormente
                        ldab LEDS
                        aba
                        staa LEDS

                        bra PT_LEDS_retornar

PT_LEDS_clr             bclr LEDS,$F8

PT_LEDS_retornar        rts                                                
