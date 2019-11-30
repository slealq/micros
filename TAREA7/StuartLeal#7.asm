;; ===========================================================================
;; Autor: Stuart Leal Quesada | B53777
;; Fecha: 29 de noviembre de 2019
;; Version: 1.0

#include registers.inc

;; ===========================================================================
;; ==================== DECLARACION DE ESTRUCTURAS DE DATOS ==================
;; ===========================================================================



;; Etiquetas
EOM:                    equ $0
N:                      equ 100
MAX_BRILLO:             equ 100

;; ==================== INICIO DE ESTRUCTURAS =================================

                        org $1000
CONT_RTI                ds 1
;;                      Banderas.0 : --              $01
;;                      Banderas.1 : --              $02
;;                      Banderas.2 : --              $04
;;                      Banderas.3 : --              $08
;;                      Banderas.4 : --              $10
;;                      Banderas.5 : SEND CMD | DATA $20
;;                      Banderas.6 : ALARM_FIRST     $40
;;                      Banderas.7 : RW_RTC          $80
Banderas                ds 1
BRILLO:                 ds 1
CONT_DIG:               ds 1
CONT_TICKS:             ds 1
DT:                     ds 1
BCD1:                   ds 1
BCD2:                   ds 1
DISP1:                  ds 1
DISP2:                  ds 1
DISP3:                  ds 1
DISP4:                  ds 1
LEDS:                   ds 1
SEGMENT:                db $3F,$06,$5B,$4F,$66,$6D,$7D,$07,$7F,$6F,$40,$00
CONT_7SEG:              ds 2    
Cont_Delay:             ds 1
Cont_Buzzer:            ds 1    ;; Estructura de datos adicional
D2ms:                   db 100
D260us:                 db 13
D40us:                  db 2
Clear_LCD:              db $01
ADD_L1:                 db $80
ADD_L2:                 db $C0
iniDISP:                db $04,$28,$28,$06,$0C
Index_RTC:              ds 1
DIR_WR:                 db $D0
DIR_RD:                 db $D1
ALARMA:                 dw $0108
T_Write_RTC:            db $00  ;; 0 segundos, activar CH=0
                        db $00  ;; 0 minutos
                        db %01001000 ;; 8 AM horas, 12 hour format
                        db $03  ;; Día número 3 (Miércoles) L:1, K:2, M:3
                        db $04  ;; Día número 4 del mes
                        db $11  ;; Mes número 11
                        db $13  ;; Año 19.

    ;; Cambiar por valores a escribir
T_Read_RTC:             ds 7

iniMensajes:
;;                      Mensajes de configuración
RELOJ_L1:               fcc '     RELOJ'
                        db EOM

RELOJ_L2:               fcc ' DESPERTADOR 623'                        
                        db EOM

;; ===========================================================================
;; ==================== DECLARACION DE INTERRUPCIONES ========================
;; ===========================================================================

                        org $3E70
                        dw RTI_ISR

                        org $3E4C
                        dw PH_ISR

                        org $3E66
                        dw OC4_ISR

                        org $3E64
                        dw OC5_ISR

                        org $3E40
                        dw IIC_ISR

;; ===========================================================================
;; ==================== RUTINA DE INICIALIZACIÓN =============================
;; ===========================================================================

                        org $2000
                        lds #$3bff                        

                        ;; Configuración de I^2C
                        movb #$1f,IBFD      
                        movb #%11010000,IBCR
                        bset IBSR,$80

                        ;; para OC4
                        movb #$90 TSCR1     ;; Habilitar TEN y FFCA
                        movb #$03 TSCR2     ;; Habilitar PRS = 8
                        movb #$10 TIOS      ;; Habiliar OC 4
                        movb #$10 TIE       ;; Empezar OC4 ON

                        ;; para teclado matricial                        
                        movb #$F0 DDRA      ;; 4msb como entradas de PORTA
                        bset PUCR,$01       ;; Pull-up en PORTA

                        ;; para RTI
                        movb #$75 RTICTL    ;; t = 1.024 ms
                        ;;bset CRGINT $80     ;; RTI enable
                        bclr CRGINT,$80

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
                        movb #$F0 PPSH
                        movb #$FF PIFH
                        movb #$0F PIEH        ;; Habilitar int PH3-PH2-PH1-PH0

                        ;; para DDRK -> LCD
                        movb #$FF DDRK             

                        ;; Habilitar interrupciones, y realizar primer
                        ;; calculo para OC4 
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
                        clr CONT_Buzzer
                        movw #5000 CONT_7SEG

                        ;; Limpiar BCD para que esté apagado al puro inicio
                        movb #$BB BCD1
                        movb #$BB BCD2
                        clr LEDS
                        movb #40 BRILLO

                        ;; Borrar el indice de RTC
                        clr Index_RTC

                        ;;  Cargar en LCD el mensaje de Reloj 623
                        ldx #RELOJ_L1
                        ldy #RELOJ_L2
                        jsr LCD

                        ;; Definir
                        bclr Banderas,$80   ;; Configurar RW_RTC = 0
                        bset Banderas,     $40   ;; ALARM_FIRST = 1 

                        ;; ELIMINAR - Configurar CLK una vez para pruebas
                        ;; Deshabilitar Fuente de Call_DS1307 mientras
                        ;; se completa la transmisión
                        bclr PIEH,$01
                        bclr CRGINT,$80
                        ;; Definir RW_RTC                        
                        bclr Banderas,$80   ;; Configurar RW_RTC = 0
                        jsr CALL_DS1307
                        ;; Habilitar RTI
                        ;;bset CRGINT,$80

;; ===========================================================================
;; ==================== PROGRAMA PRINCIPAL ===================================
;; ===========================================================================

MAIN                    ldx BCD1    ;; Esto trae a BCD2 también que seguido

                        cpx ALARMA
                        beq MAIN_set_alarm

                        bset Banderas,$40   ;; Volver a dejar ALARM_FIRST = 1

                        bra MAIN

                        ;; Si ALARM_FIRST = 0, entonces ya se encendio la alarma
MAIN_set_alarm          brclr Banderas,$40,MAIN     

                        bset TIE,$20
                        bset TIOS,$20
                        bclr Banderas,$40   ;; Poner ALARM_FIRST = 0

                        ;; Configurar primera interrupción de OC5
                        ldd TCNT
                        addd #100
                        std TC5

                        bra MAIN


;; ===========================================================================
;; ==================== SUBRUTINAS DE INTERRUPCIONES =========================
;; ===========================================================================

;; ==================== Subrutina IIC_ISR ====================================

                        ;; Borrar bandera de interrupción
IIC_ISR                 bset IBSR,$02

                        ;; Verificar si bandera de RW_RTC está en 0
                        brclr Banderas,$80,IIC_write_isr

                        ;; Bandera en 1, lo que significa lectura
                        jsr READ_RTC

                        bra IIC_retornar

                        ;; Bandera en 0, lo que significa escritura
IIC_write_isr           jsr WRITE_RTC                                                

IIC_retornar            rti

;; ==================== Subrutina RTI_ISR ====================================
;; Descripción: Realiza la lectura del RTC cada segundo.

RTI_ISR                 bset CRGFLG,$80    ;; limpiar bander int

                        tst CONT_RTI
                        beq RTI_set_and_return

                        ;; No, decrementar y regresar
                        dec CONT_RTI
                        bra RTI_retornar

RTI_set_and_return      ;; Cargar valor para un segundo
                        movb #20 CONT_RTI ;; 20 * 50ms = 1seg

                        ;; Definir la bandera de RW_RTC
                        bset Banderas,$80
                        jsr CALL_DS1307

                        ;; Leer los datos y guardarlos en BCD1 y BCD2
                        ;; con MM en BCD1 y HH en BCD2
                        ldx #T_Read_RTC
                        ldaa #1
                        movb a,x BCD1
                        ldaa #2
                        movb a,x BCD2
                        bclr BCD2,$40   ;; Elimiar el 12/24 bit de la hora
                        bclr BCD2,$20   ;; Elimiar el AM/PM bit de la hora

RTI_retornar            rti

;; ==================== Subrutina OC4_ISR ====================================
;; Descripción: Subrutina de interrupción, utilizada para controlar LEDS.
;;
;;  - Con el contador CONT_7SEG, se controla que cada 100ms se haga la
;;  conversión de BCD hasta DISP.
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
                        bne OC4_Retornar
 
                        ;; Caso donde CONT_7SEG = 0
                        jsr BCD_7SEG
                        movw #5000 CONT_7SEG

OC4_Retornar            rti

;; ==================== Subrutina OC5_ISR ====================================

OC5_ISR                 ldd TCNT
                        addd #100
                        std TC5

                        ;; Verficar si Cont_Buzzer = 3
                        ldaa Cont_Buzzer
                        cmpa #3
                        beq OC5_prepare_set

                        ;; Caso donde Cont_Buzzer no es igual a 3
                        ;; Verificar si Cont_Buzzer = 1
                        cmpa #1
                        beq OC5_prepare_noset

                        ;; Ir a incrementer Buzzer
                        bra OC5_inc_buzzer

OC5_prepare_set         ;; Caso donde Cont_Buzzer = 3
                        bset TCTL1,$08  ;; TCTL1.3
                        bset TCTL1,$04  ;; TCTL1.2
                        clr Cont_Buzzer

                        bra OC5_retornar

                        ;; Caso donde Cont_Buzzer = 1
OC5_prepare_noset       bset TCTL1,$08  ;; TCTL1.3
                        bclr TCTL1,$04  ;; TCTL1.2

                        ;; Caso donde no es ninguna de las anteriores
OC5_inc_buzzer          inc Cont_Buzzer

OC5_retornar            rti

;; ==================== Subrutina PH_ISR =====================================

                        ;; Verificar si la interrupción es por PH0
PH_ISR                  brset PIFH,$01,PH_call_write

                        ;; Verificar si la interrupción es por PH1
                        brset PIFH,$02,PH_clr_alarm

                        ;; Verificar si la interrupción es por PH2
                        brset PIFH,$04,PH_dec_brightness

                        ;; Si no, la interrupción tiene que ser por PH3'
                        ldaa BRILLO
                        cmpa #100
                        beq PH_clr_ph3

                        ;; Caso en que no hay llegado al limite, incrementar
                        adda #5
                        staa BRILLO

                        ;; Resetear interrupción PH3
PH_clr_ph3              bset PIFH,$08

                        bra PH_retornar

PH_call_write           ;; Caso en que es el Ph0      
                        bclr Banderas,$80       ;; Limpiar RW_RTC
                        jsr CALL_DS1307
                        bset PIFH,$01

                        bra PH_retornar

                        ;; Caso en que es el Ph1
PH_clr_alarm            bclr TIE,$20
                        bclr TIOS,$20

                        bset PIFH,$02

                        bra PH_retornar

                        ;; Caso en que es el PH2
PH_dec_brightness       tst BRILLO
                        beq PH_clr_ph2

                        ;; Decrementar brillo
                        ldaa BRILLO
                        suba #5
                        staa BRILLO

PH_clr_ph2              ;; Resetear interrupción PH2
                        bset PIFH,$04                               

PH_retornar             rti

;; ===========================================================================
;; ==================== SUBRUTINAS GENERALES =================================
;; ===========================================================================

;; ==================== CALL_DS1307 ==========================================

CALL_DS1307             ;; Deshabilitar Fuente de Call_DS1307 mientras
                        ;; se completa la transmisión
                        bclr PIEH,$01
                        bclr CRGINT,$80

                        ;; Configuración para enviar calling address
                        bset IBCR,$10 ;; MODO TX
                        bset IBCR,$20 ;; IBCR.5 = 1, START BIT

CD_prepare_wr           movb DIR_WR,IBDR

CD_return               rts

;; ==================== Subrutina READ_RTC ===================================                        

                        ;; Verificar si es la primera vez que se entra
                        ;; en esta subrutina, después de un llamado
READ_RTC                ldaa Index_RTC
                        cmpa #0
                        beq RR_word_address

                        ;; Caso en que no es la primera vez
                        ;; Verificar si es la segunda vez
                        cmpa #1
                        beq RR_Started_repeat

                        ;; Caso en que no es la segunda
                        ;; Verificar si es la tercera vez
                        cmpa #2
                        beq RR_Invert_txrx

                        ;; Caso en que no es la tercera
                        ;; Verificar si es la última
                        cmpa #10
                        beq RR_restore_settings

                        ;; Caso en que no es la última
                        ;; Verificar si es la penultima
                        cmpa #9
                        beq RR_prepare_stop
                        
                        ;; En caso de que no, ir a get_data
                        bra RR_get_data

                        ;; Caso donde es la primera int
RR_word_address         clr IBDR            ;; Mandar ADD de segundos

                        bra RR_inc_index

                        ;; Caso en donde es la segunda int
RR_Started_repeat       bset IBCR,$04       ;; Poner repeated started
                        movb DIR_RD IBDR    ;; Calling Address de READ

                        bra RR_inc_index

                        ;; Caso en donde es la tercer int
RR_Invert_txrx          bclr IBCR,$04       ;; Apagar repeated started
                        bclr IBCR,$10       ;; Master en recepeción
                        bclr IBCR,$08       ;; Enviar ACK en bit 9

                        ldaa IBDR           ;; Iniciar lectura dummy

                        bra RR_inc_index

                        ;; Caso en que es la última int
RR_restore_settings     bclr IBCR,$08       ;; Habilitar ACK en TX * REVISAR
                        bset IBCR,$10       ;; Master en Transmisión
                        clr Index_RTC
                        bclr IBCR,$20       ;; Mandar STOP
                        movb #$0F PIEH      ;; Re-habilitar puerto H

                        bset CRGINT,$80     ;; Re-habilitar RTI
                        bset PIEH,$01       ;; Re-habilitar PH0

                        bra RR_retornar

                        ;; Caso en que la transmisión es antepenultima
RR_prepare_stop         bset IBCR,$08       ;; NO Enviar ACK en bit 9

                        ;; Guardar los datos
RR_get_data             suba #3
                        ldx #T_Read_RTC
                        ;; Inicia nueva secuencia
                        movb IBDR a,x         

RR_inc_index            inc Index_RTC

RR_retornar             rts
                        
;; ==================== Subrutina WRITE_RTC ==================================                        

WRITE_RTC               ldaa Index_RTC

                        ;; Verificar si es la primera interrupción
                        cmpa #0
                        beq WR_send_add

                        ;; Verificar si es la última interrupción
                        cmpa #8
                        beq WR_clr_index

                        ;; Caso en donde NO es la primera interrupción
                        ;; Ni tampoco la última
                        ;; Enviar info desde el master al RTC
                        ldx #T_Write_RTC
                        ldab Index_RTC
                        subb #1
                        movb b,x IBDR

                        ;; Verificar si era la penúltima interrupcón
                        cmpa #7
                        beq WR_stopbit_int

                        ;; Caso en que no era la penúltima interrupción
                        bra WR_inc_and_return

WR_stopbit_int          ;; Caso en que era la penúltima interrupción
                        bclr IBCR,$20   ;; Transición 1->0 STOP SIGNAL

                        bra WR_inc_and_return

WR_clr_index            ;; Caso en que era la última interrupción
                        clr Index_RTC
                        bset PIEH,$01
                        bset CRGINT,$80

                        bra WR_retornar

WR_send_add             ;; Mandar add de segundo 00
                        clr IBDR
                        
                        ;; Incrementar Index
WR_inc_and_return       inc Index_RTC

WR_retornar             rts

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

                        ;; Agregar lógica para segundos
                        ldaa T_Read_RTC     ;; Cargar segundos, primera pos
                        anda #$01

                        ;; Verificar si segundos = 0
                        cmpa #0
                        beq BCD_7s_return

                        ;; Caso donde segundos = 1, activar :
                        bset DISP3,$80
                        bset DISP2,$80

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

                        brclr Banderas,$20,SE_cmd_h

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

                        brclr Banderas,$20,SE_cmd_l

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
                        bclr Banderas,$20

                        jsr SEND

                        movb D40us Cont_Delay

                        jsr DELAY

                        incb

                        bra LC_tst_fin

LC_clr                  ldaa Clear_LCD
                        bclr Banderas,$20

                        jsr SEND

                        movb D2ms Cont_Delay

                        pulx

                        jsr DELAY

                        jsr CARGAR_LCD

                        rts      

;; ==================== Subrutina CARGAR_LCD =================================

CARGAR_LCD              ldaa ADD_L1
                        bclr Banderas,$20

                        jsr SEND

                        movb D40us Cont_Delay

                        jsr DELAY

CLCD_ld_l1              ldaa 1,x+

                        cmpa #EOM
                        beq CLDC_l2

                        bset Banderas,$20

                        jsr SEND

                        movb D40us Cont_Delay

                        jsr DELAY

                        bra CLCD_ld_l1

CLDC_l2                 ldaa ADD_L2
                        bclr Banderas,$20

                        jsr SEND

                        movb D40us Cont_Delay

                        jsr DELAY

CLCD_ld_l2              ldaa 1,y+

                        cmpa #EOM
                        beq CLCD_return

                        bset Banderas,$20

                        jsr SEND

                        movb D40us Cont_Delay

                        jsr DELAY

                        bra CLCD_ld_l2

CLCD_return             rts   