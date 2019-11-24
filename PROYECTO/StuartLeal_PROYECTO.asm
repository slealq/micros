;; ===========================================================================
;; Autor: Stuart Leal Quesada | B53777
;; Fecha: 19 de noviembre de 2019
;; Version: 1.0
;; Explicación:
;;
;;  - Este programa implementa la solución de software llamada RADAR 623.
;;  Este radar, se encarga de medir la velocidad de un vehículo, y indicarle
;;  al conductor del vehículo, su velocidad, el límite de velocidad, y 
;;  alertarlo si su velocidad exede este límite.
;;
;;  - Hay tres modos de funcionamiento:
;;      + MODO LIBRE: En este modo el sistema está ocioso, y no se realiza
;;                    ningún cálculo.
;;      + MODO MEDICIÓN: En este modo el sistema está funcionando, y mide
;;                       la velocidad, basado en el tiempo que le toma a un
;;                       vehículo pasar entre dos sensores, conectados en PH3
;;                       y PH0.
;;                       La velocidad es desplegada utilizando los displays de
;;                       siete segmentos de la tarjeta Dragon 12.
;;      + MODO CONFIG: En este modo, el sistema permite la configuración de
;;                     la velocidad máxima. Se utiliza el teclado matricial
;;                     para meter datos, y las teclas de Enter y Borrar para
;;                     manipular la entrada de datos.
;;
;;  - Listado de las subrutinas (en orden):
;;      + ATD0_ISR
;;      + TCNT_ISR
;;      + CALCULAR
;;      + OC4_ISR
;;      + MUX_TECLADO
;;      + TAREA_TECLADO
;;      + FORMAR_ARRAY
;;      + MODO_RUN
;;      + MODO_CONFIG
;;      + BCD_BIN
;;      + BIN_BCD
;;      + Single_BIN_BCR
;;      + BCD_7SEG
;;      + DELAY
;;      + SEND
;;      + LCD
;;      + CARGAR_LCD
;;      + PATRON_LEDS
;;      + CONV_BIN_BCD
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
;;                      Banderas.5 : CFG_FIRST      $20
;;                      Banderas.6 : MED_FIRST      $40
;;                      Banderas.7 : LIB_FIRST      $80
;;                      => Se manejan con Banderas,[$01,$02,$04,$08,$10,..]
;;                      Banderas.8 : SEND_CMD (0) or SEND_DATA (1)
Banderas                dw 1
;;                      Variables para MODO_CONFIG
;;                      Variables para TAREA_TECLADO
;;                      Variables para ATD_ISR
BRILLO:                 ds 1
POT:                    ds 1
;;                      Variables para PANT_CONTRL
TICK_EN:                ds 2
TICK_DIS:               ds 2
;;                      Variables para CALCULAR
VELOC:                  ds 1
TEMP:                   ds 1
TEMP2:                  ds 1
Reb_shot                ds 1
;;                      Variables para TCNT_ISR
TICK_VEL:               ds 1
;;                      Variables para CONV_BIN_BCD
;;                      Variables para BIN_BCD
BCD_L:                  ds 1
BCD_H:                  ds 1      
;;                      Variables para BCD_7SEG    
;;                      Variables para PATRON_LEDS  
;;                      Variables para OC4_ISR
CONT_DIG:               ds 1
CONT_TICKS:             ds 1
DT:                     ds 1
CONT_7SEG:              dw 1                  
CONT_200:               dw 1                  
;;                      Variables viejas
MAX_TCL:                db 2        ;; Set de valor MAX_TCL
Tecla:                  ds 1
Tecla_in:               ds 1
Cont_reb:               ds 1
Cont_TCL:               ds 1
Patron:                 ds 1
Cuenta:                 ds 1
Acumul:                 ds 1
CPROG:                  ds 1
VMAX:                   db 250
TIMER_CUENTA:           ds 1
LEDS:                   db 1
BIN1:                   db 0
BIN2:                   db 0
LOW:                    ds 1
BCD1:                   ds 1
BCD2:                   ds 1
DISP1:                  db 1
DISP2:                  db 1
DISP3:                  db 1
DISP4:                  db 1
Cont_Delay:             ds 1
D2ms:                   db 100
D260us:                 db 13
D40us:                  db 2
Clear_LCD:              db $01
ADD_L1:                 db $80
ADD_L2:                 db $C0

                        org $1040
Num_Array:              ds 6

                        org $1050
Teclas:                 db $01,$02,$03,$04,$05,$06,$07,$08,$09,$0B,$0,$0E

                        org $1060
SEGMENT:                db $3F,$06,$5B,$4F,$66,$6D,$7D,$07,$7F,$6F

                        org $1070
iniDISP:                db $04,$28,$28,$06,$0C

                        org $1080
iniMensajes:
config_l1:              fcc 'MODO CONFIG'
                        db EOM

config_l2:              fcc 'INGRESE CPROG.'                        
                        db EOM

run_l1:                 fcc 'MODO RUN'                        
                        db EOM

run_l2:                 fcc 'ACUMUL.-CUENTA'      
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
;; ==================== RUTINA DE INICIACIÓN =================================
;; ===========================================================================

                        org $2000
                        lds #$3bff                        

                        ;; CONFIGURACION DE ATD0
                        ldab 200
                        movb #$C2 ATD0CTL2

MN_wait_10us            dbne b,MN_wait_10us

MN_After_10us           movb #$30 ATD0CTL3
                        movb #$BF ATD0CTL4
                        movb #$87 ATD0CTL5

                        ;; para OC4
                        movb #$90 TSCR1     ;; Habilitar TEN y FFCA
                        movb #$03 TSCR2     ;; Habilitar PRS = 8
                        movb #$10 TIOS      ;; Habiliar OC 4
                        movb #$10 TIE       ;; Empezar oc
                        bset TSCR2,$80      ;; habilitar interrupciones por rebase

                        ;; para teclado matricial                        
                        movb #$F0 DDRA      ;; 4msb como entradas de PORTA
                        bset PUCR,$01       ;; Pull-up en PORTA

                        ;; para RTI
                        movb #$40 RTICTL    ;; t = 1.024 ms
                        bset CRGINT $80     ;; RTI enable

                        ;; para DDRK -> LCD
                        movb #$FF DDRK 

                        cli                 ;; I = 0

                        ldd TCNT            ;; Primer oc
                        addd #14
                        std TC4                   

                        ;; habilitar puerto b como salidas
                        movb #$FF DDRB

                        ;; habilitar puerto j (tierra de leds)     
                        bset DDRJ,$02

                        ;; habilitar rele de microcontrolador
                        bset DDRE,$04

                        ;; habilitar puerto p (tierras de disp)
                        movb #$0F DDRP

                        ;; habilitar puerto boton: 0,1,2,3,7 y flanco dec
                        clr DDRH
                        movb #$09 PIEH      ;; habilitar interrupcion PH3 y PH0
                        movb #$F0 PPSH
                        movb #$FF PIFH

;; ===========================================================================
;; ==================== PROGRAMA PRINCIPAL ===================================
;; ===========================================================================

                        ;; inicializar estructuras de datos
                        clr CONT_DIG
                        clr CONT_TICKS
                        movw #5000 CONT_7SEG

                        clr CPROG
                        clr Acumul
                        clr Cuenta

                        clr Banderas
                        clr Banderas+1

                        movb #$FF Tecla
                        movb #$FF Tecla_in
                        clr Cont_TCL
                        movb #10 Cont_reb

                        ldx #config_l1
                        ldy #config_l2
                        jsr LCD

                        ;; empieza main

; repeat                  ldx #config_l1
;                         ldy #config_l2

;                         jsr CARGAR_LCD

;                         jsr BIN_BCDx
;                         bra repeat                        


                        ;; ignorar todo esto de momento
MN_check_cprog          tst CPROG
                        beq MN_CFG_check_first

                        ;; TCL LISTA
                        brset Banderas+1,$20,MN_CFG_check_first

                        ;; TCL_LEIDA
                        brset Banderas+1,$40,MN_RUN_first

                        bra MN_jsr_run

MN_RUN_first            ldx #run_l1
                        ldy #run_l2

                        jsr CARGAR_LCD

                        ;; TCL_LEIDA
                        bclr Banderas+1,$40
                        movb #$01 LEDS
                        movb #$0F PIEH
                        
                        clr ACUMUL
                        clr CUENTA

MN_jsr_run              jsr MODO_RUN

                        bra MN_jsr_bin_bcd

MN_CFG_check_first      brclr Banderas+1,$40,MN_CFG_first

                        bra MN_jsr_config

MN_check_cprog_local    bra MN_check_cprog

MN_CFG_first            ldx #config_l1
                        ldy #config_l2

                        jsr CARGAR_LCD

                        bset Banderas+1,$40
                        movb #$FF BIN2
                        movb CPROG BIN1
                        movb #$02 LEDS
                        movb #$0C PIEH

                        bclr PORTE,$04

                        ;; borrar num_array con FF - BEGIN
                        bclr Banderas+1,$04
                        clra
                        ldab #6             ;; limpiar Num_array
                        ldx #Num_Array

MN_Check_CleanFin       cba
                        beq MN_jsr_config

                        movb #$FF a,x
                        inca

                        bra MN_Check_CleanFin
                        ;; borrar num_array con FF - END

MN_jsr_config           jsr MODO_CONFIG                                                

MN_jsr_bin_bcd          jsr BIN_BCDx

                        brclr PTIH,$80,MN_set_md_run

                        bset Banderas+1,$20

                        bra MN_check_cprog_local

MN_set_md_run           bclr Banderas+1,$20

                        bra MN_check_cprog_local                                            

MN_fin                  bra *

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
;;      - BRILLO: Variable tipo byte, con un valor de 0 a 100. Define el
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
;;  - Con esta subrutina, CALCULO realiza los cálculos de velocidad, mediante
;;  el uso la variable TICK_VEL.
;;  Además, se realiza el conteo de tiempo para encender el DISPLAY con el
;;  mensaje adecuado, de acuerdo a la posición del vehículo, utilizando las
;;  variables TICK_EN y TICK_DIS.
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
;;      - VELOC:     Indica la velocidad calculada. Esta interrupción borra
;;                   esta variable cuando TICK_EN = TICK_DIS = 0
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
                        ;;clr VELOC

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

CALCULAR                movb Cont_reb Reb_shot                  ;; BORRAR
                        tst Cont_reb
                        bne Calc_rst_and_return

                        brset PIFH,$08,Calc_rst_tick_vel
                        brset PIFH,$01,Calc_veloc

                        ;; si no es ni PH0 ni PH3, borrar todas
                        ;; y retornar
Calc_rst_and_return     movb #$FF PIFH
                        bra Calc_retornar

Calc_rst_tick_vel       ;; caso de PH3
                        inc BIN2                            ;; BORRAR
                        clr TICK_VEL
                        bset Banderas,$80

                        bset PIFH,$08

                        bra Calc_set_cntr

Calc_veloc              ;; caso de PH0
                        brclr Banderas,$80,Calc_reset_ph0

                        inc BIN1                        ;; BORRAR

                        ;; calcular denominador
                        ldaa TICK_VEL
                        staa TEMP                       ;; BORRAR
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

                        ;;movb VELOC,TEMP2                ;; BORRAR
                        movb VELOC,LEDS                 ;; BORRAR

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

;; ==================== Subrutina MODO_RUN ===================================

MODO_RUN                ldaa CUENTA
                        cmpa CPROG

                        beq MR_update_and_return

                        tst TIMER_CUENTA
                        beq MR_inc_cuenta

                        bra MR_update_and_return

MR_inc_cuenta           movb VMAX TIMER_CUENTA
                        inc CUENTA
                        ldaa CUENTA

                        cmpa CPROG
                        beq MR_inc_acumul

                        bra MR_update_and_return

MR_inc_acumul           inc ACUMUL
                        bset PORTE,$04     

                        ldaa ACUMUL
                        cmpa #99
                        bhi MR_clr_acumul

                        bra MR_update_and_return

MR_clr_acumul           clr ACUMUL

MR_update_and_return    movb CUENTA BIN1
                        movb ACUMUL BIN2

                        rts                                                       

;; ==================== Subrutina MODO_CONFIG ================================

MODO_CONFIG             tst CPROG
                        beq MC_set_bin1

                        bra MC_check_bd2

MC_set_bin1             movb CPROG BIN1

MC_check_bd2            brclr Banderas+1,$04,MC_jsr_tarea_teclado

                        ldab CPROG
                        pshb

                        jsr BCD_BIN
                        pulb

                        ldaa CPROG
                        cmpa #11
                        bhi MC_check_96

                        bra MC_restore_cprog

MC_check_96             cmpa #97
                        blo MC_change_bin1

                        bra MC_restore_cprog

MC_change_bin1          movb CPROG BIN1
    	                bra MC_clear_num_array

MC_restore_cprog        stab CPROG

MC_clear_num_array      ;; borrar num_array con FF - BEGIN
                        bclr Banderas+1,$04
                        clra
                        ldab #6             ;; limpiar Num_array
                        ldx #Num_Array

MC_Check_CleanFin       cba
                        beq MC_fin

                        movb #$FF a,x
                        inca

                        bra MC_Check_CleanFin
                        ;; borrar num_array con FF - END                 

MC_jsr_tarea_teclado    jsr TAREA_TECLADO                                                                                                         

MC_fin                  rts      

;; ==================== Subrutina BCD_BIN ==================================== 

BCD_BIN                 ldx #Num_Array
                        clra
                        clr CPROG

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
                        addb CPROG
                        stab CPROG
                        pula

                        bra BCD_B_check_unit   

BCD_B_add_unit          ldab 0,x
                        addb CPROG
                        stab CPROG

                        rts       

;; ==================== Subrutina BIN_BCD ====================================                                                                

BIN_BCDx                ldaa BIN1
                        cmpa #99

                        bhi BIN_disable_1

                        jsr BIN_BCD

                        movb BCD_L BCD1

                        bra BIN_check_bin2

BIN_disable_1           movb #$FF BCD1

BIN_check_bin2          ldaa BIN2
                        cmpa #99 

                        bhi BIN_disable_2

                        jsr BIN_BCD

                        movb BCD_L BCD2 

                        bra BIN_fin

BIN_disable_2           movb #$FF BCD2

BIN_fin                 rts                        

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

BCD_7SEG                ldaa BCD2
                        ldx #SEGMENT

                        cmpa #$FF
                        beq BCD_7s_clr_bcd2

                        anda #$0F
                        movb a,x DISP2

                        ldaa BCD2
                        lsra 
                        lsra
                        lsra
                        lsra
                        
                        cmpa #0
                        beq BCD_save_ff_disp1

                        movb a,x DISP1

                        bra BCD_7s_put_bcd2

BCD_save_ff_disp1       movb #00 DISP1

                        bra BCD_7s_put_bcd2

BCD_7s_clr_bcd2         movb #$00 DISP2
                        movb #$00 DISP1                        

BCD_7s_put_bcd2         ldaa BCD1

                        cmpa #$FF
                        beq BCD_7s_clr_bcd1

                        anda #$0F
                        ldx #SEGMENT

                        movb a,x DISP4

                        ldaa BCD1
                        lsra
                        lsra
                        lsra
                        lsra
                        
                        cmpa #0
                        beq BCD_save_ff_disp2

                        movb a,x DISP3

                        bra BCD_7s_return

BCD_save_ff_disp2       movb #00 DISP3     

                        bra BCD_7s_return

BCD_7s_clr_bcd1         movb #$00 DISP4
                        movb #$00 DISP3                        

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

;; ==================== Subrutina CONV_BIN_BCD ================================

CONV_BIN_BCD            rts