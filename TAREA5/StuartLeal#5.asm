;; ===========================================================================
;; Autor: Stuart Leal Q
;; Fecha: 25 de Octubre de 2019
;; Version: 1.0
;; ===========================================================================

#include registers.inc

;; ===========================================================================
;; ==================== DECLARACION DE ESTRUCTURAS DE DATOS ==================
;; ===========================================================================

                        org $1000

EOM:                    equ $0
N:                      equ 100                        

MAX_TCL:                db 2        ;; Set de valor MAX_TCL
Tecla:                  ds 1
Tecla_in:               ds 1
Cont_reb:               ds 1
Cont_TCL:               ds 1
Patron:                 ds 1
Banderas:               ds 1
Num_Array:              ds 6
Teclas:                 db $01,$02,$03,$04,$05,$06,$07,$08,$09,$0B,$0,$0E
Cuenta:                 ds 1
Acumul:                 ds 1
CPROG                   ds 1
LEDS:                   db $ff
BRILLO:                 db 50
CONT_DIG:               ds 1
CONT_TICKS:             ds 1
DT:                     ds 1
BIN1:                   db 99
BIN2:                   db 14
LOW:                    ds 1
BCD1:                   ds 1
BCD2:                   ds 1
DISP1:                  db 1
DISP2:                  db 1
DISP3:                  db 1
DISP4:                  db 1
SEGMENT:                db $3F,$06,$5B,$4F,$66,$6D,$7D,$07,$7F,$6F
CONT_7SEG:              ds 1
Cont_Delay:             ds 1
D2ms:                   db 100
D260us:                 db 13
D40us:                  db 2
Clear_LCD:              db $01
ADD_L1:                 db $80
ADD_L2:                 db $C0
iniDISP:                db $04,$28,$28,$06,$0C
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

                        org $3e4c
                        dw PH_ISR

                        org $3E66
                        dw TC4_ISR                        

;; ===========================================================================
;; ==================== CODIFICACION HARDWARE ================================
;; ===========================================================================

                        org $2000
                        lds #$3bff

                        ;; para OC4
                        movb #$90 TSCR1     ;; Habilitar TEN y FFCA
                        movb #$05 TSCR2     ;; Habilitar PRS = 32
                        movb #$10 TIOS      ;; Habiliar OC 4
                        movb #$00 TCTL1     ;; Disable PT4
                        movb #$00 TCTL2 
                        movb #$10 TIE       ;; Empezar oc

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
                        movb #$0C PIEH
                        movb #$F0 PPSH
                        movb #$FF PIFH

;; ===========================================================================
;; ==================== PROGRAMA PRINCIPAL ===================================
;; ===========================================================================

                        ;; inicializar estructuras de datos
                        clr CONT_DIG
                        clr CONT_TICKS
                        movb #5000 CONT_7SEG

                        clr CPROG
                        clr Acumul
                        clr Cuenta

                        clr Banderas

                        ;; empieza main

MN_check_cprog          tst CPROG
                        beq MN_CFG_check_first

                        brset Banderas,$10,MN_CFG_check_first

                        brset Banderas,$20,MN_RUN_first

                        bra MN_jsr_run

MN_RUN_first            ldx #run_l1
                        ldy #run_l2

                        jsr LCD

                        bclr Banderas,$20
                        movb #$01 LEDS
                        movb #$FF BIN2

MN_jsr_run              jsr MODO_RUN

                        bra MN_jsr_bin_bcd

MN_CFG_check_first      brclr Banderas,$20,MN_CFG_first

                        bra MN_jsr_config

MN_CFG_first            ldx #config_l1
                        ldy #config_l2

                        jsr LCD

                        bset Banderas,$20
                        movb #$02 LEDS

MN_jsr_config           jsr MODO_CONFIG                                                

MN_jsr_bin_bcd          jsr BIN_BCD

                        brclr PTIH,$80,MN_set_md_run

                        bset Banderas,$10

                        bra MN_check_cont_reb

MN_set_md_run           bclr Banderas,$10

MN_check_cont_reb       tst Cont_Reb
                        beq MN_enable_ph_interrupt

                        bra MN_check_cprog

MN_enable_ph_interrupt  brset Banderas,$10,MN_enable_ph_config

                        movb #$0F PIEH

                        bra MN_check_cprog

MN_enable_ph_config     movb #$0C PIEH

                        bra MN_check_cprog                                                

MN_fin                  bra *

                        ;; main viejo

                        movb #$FF Tecla
                        clr Cont_TCL
                        movb #$FF Tecla_in
                        clr Banderas
                        movb #10 Cont_Reb

                        ;; llamar LCD
                        ldx #config_l1
                        ldy #config_l2
                        jsr LCD    

                        ;; llamar a BIN_BCD
                        jsr BIN_BCD

                        ;; borrar num_array con FF
                        clra
                        ldab #6             ;; limpiar Num_array
                        ldx #Num_Array

MN_Check_CleanFin       cba
                        beq MN_ARRAY_OK

                        movb #$FF a,x
                        inca

                        bra MN_Check_CleanFin                    

                        ;; logica para array_ok

MN_ARRAY_OK             brset Banderas,$04,Skip_tcl_read

                        ;; test ph
                        bra fin
                        ;; test ph

Tcl_read                jsr TAREA_TECLADO

                        bra MN_ARRAY_OK

Skip_tcl_read           jsr BCD_BIN
                        ;; bra MN_ARRAY_OK                        

fin                     bra *

;; ==================== Subrutina MUX_TECLADO ================================ 

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

TAREA_TECLADO           tst Cont_reb
                        bne TT_Return

                        jsr MUX_TECLADO

                        ldaa Tecla        ;; (Tecla) = $FF
                        cmpa #$FF 
                        beq TT_Check_antirebote

                        brset Banderas,$02,TT_Check_tecla_igual

                        movb Tecla Tecla_in
                        bset Banderas,$02 ;; TCL_LEIDA <- 1
                        movb #10 Cont_reb

                        bra TT_Return

TT_Check_antirebote     brset Banderas,$01,TT_go_formar_array
                        bra TT_Return

TT_go_formar_array      bclr Banderas,$02
                        bclr Banderas,$01

                        jsr FORMAR_ARRAY

                        bra TT_Return                     

TT_Check_tecla_igual    ldaa Tecla_in
                        cmpa Tecla
                        beq TT_Set_tecla_lista

                        movb #$FF Tecla
                        bclr Banderas,$02   ;; TCL_LEIDA
                        bclr Banderas,$01   ;; TCL_LISTA
                        movb #$FF Tecla_in

                        bra TT_Return

TT_Set_tecla_lista      bset Banderas,$01   ;; TCL_LISTA <- 1                                     

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

FA_Middle_End           bset Banderas,$04    ;; Array_ok <- 1
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
                        bset Banderas,$04  ;; Array_ok <- 1

                        bra FA_Return

FA_Last_Erase           dec Cont_TCL
                        ldab Cont_TCL
                        ldx #Num_Array        
                        movb #$FF b,x                                                                                                                

FA_Return               rts

;; ==================== Subrutina MODO_RUN ===================================

MODO_RUN                rts

;; ==================== Subrutina MODO_RUN ===================================

MODO_CONFIG             ldaa Num_Array
                        cmpa #$FF

                        beq MC_fin

                        movb #1 CPROG

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

BIN_BCD                 ldaa BIN1
                        cmpa #99

                        bhi BIN_disable_1

                        jsr Single_BIN_BCR

                        stab BCD1

                        bra BIN_check_bin2

BIN_disable_1           movb #$FF BCD1

BIN_check_bin2          ldaa BIN2
                        cmpa #99 

                        bhi BIN_disable_2

                        jsr Single_BIN_BCR

                        stab BCD2 

                        bra BIN_fin

BIN_disable_2           movb #$FF BCD2

BIN_fin                 rts                        

;; ==================== Subrutina Single_BIN_BCR =============================      

Single_BIN_BCR          ldy #7
                        clrb 

SBB_rotate              lsla
                        rolb

                        psha

                        tfr b,a
                        anda #$0F

                        cmpa #5
                        bhs SBB_sum_3

                        bra SBB_store_low

SBB_sum_3               adda #3

SBB_store_low           staa LOW 

                        tfr b,a
                        anda #$F0

                        cmpa #$50
                        bhs SBB_sum_30

                        bra SBB_add_low

SBB_sum_30              adda #$30

SBB_add_low             adda LOW
                        tfr a,b
                        pula

                        dbeq y,SBB_return

                        bra SBB_rotate

SBB_return              lsla
                        rolb

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
                        
                        movb a,x DISP1

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
                        
                        movb a,x DISP3

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

                        brclr Banderas,$80,SE_cmd_h

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

                        brclr Banderas,$80,SE_cmd_l

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
                        bclr Banderas,$80

                        jsr SEND

                        movb D40us Cont_Delay

                        jsr DELAY

                        incb

                        bra LC_tst_fin

LC_clr                  ldaa Clear_LCD
                        bclr Banderas,$80

                        jsr SEND

                        movb D2ms Cont_Delay

                        pulx

                        jsr DELAY

                        jsr Cargar_LCD

                        rts      

;; ==================== Subrutina Cargar_LCD =================================

CARGAR_LCD              ldaa ADD_L1
                        bclr Banderas,$80

                        jsr SEND

                        movb D40us Cont_Delay

                        jsr DELAY

CLCD_ld_l1              ldaa 1,x+

                        cmpa #EOM
                        beq CLDC_l2

                        bset Banderas,$80

                        jsr SEND

                        movb D40us Cont_Delay

                        jsr DELAY

                        bra CLCD_ld_l1

CLDC_l2                 ldaa ADD_L2
                        bclr Banderas,$80

                        jsr SEND

                        movb D40us Cont_Delay

                        jsr DELAY

CLCD_ld_l2              ldaa 1,y+

                        cmpa #EOM
                        beq CLCD_return

                        bset Banderas,$80

                        jsr SEND

                        movb D40us Cont_Delay

                        jsr DELAY

                        bra CLCD_ld_l2

CLCD_return             rts                                                                        

;; ==================== Subrutina RTI_ISR ==================================== 

RTI_ISR                 bset CRGFLG,$80    ;; limpiar bander int

                        tst Cont_reb
                        beq RTI_retornar

                        dec Cont_reb

RTI_retornar            rti       

;; ==================== Subrutina PH_ISR ===================================== 

PH_ISR                  tst Cont_Reb
                        beq PH_Check_button

                        movb #$FF PIFH
                        bra PH_local_return

PH_Check_button         brset PIFH,$01,PH_save_tecla0
                        brset PIFH,$02,PH_save_tecla1
                        brset PIFH,$04,PH_save_tecla2
                        brset PIFH,$08,PH_save_tecla3

                        movb #$FF Tecla
                        bra PH_check_rebote

PH_save_tecla0          bset PIFH,$01
                        movb #0 Tecla

                        bra PH_check_rebote

PH_save_tecla1          bset PIFH,$02
                        movb #1 Tecla

                        bra PH_check_rebote

PH_save_tecla2          bset PIFH,$04
                        movb #2 Tecla

                        bra PH_check_rebote                        

PH_save_tecla3          bset PIFH,$08
                        movb #3 Tecla

PH_check_rebote         brset Banderas,$01,PH_check_same

                        movb Tecla Tecla_in
                        bset Banderas,$01
                        movb #10 Cont_Reb

PH_local_return         bra PH_return

PH_check_same           ldaa Tecla_in
                        cmpa Tecla

                        beq PH_do_action

                        movb #$FF Tecla
                        movb #$FF Tecla_in
                        bclr Banderas,$01

                        bra PH_return

PH_do_action            tst Tecla
                        beq PH_do_0

                        ldaa Tecla
                        cmpa #1
                        beq PH_do_1

                        cmpa #2
                        beq PH_do_2

                        cmpa #3
                        beq PH_do_3   

PH_l_clear_and_return   bra PH_clear_and_return                     

PH_do_0                 clr Cuenta       
                        bra PH_clear_and_return

PH_do_1                 clr Acumul
                        bra PH_clear_and_return

PH_do_2                 tst BRILLO
                        beq PH_clear_and_return

                        ldaa BRILLO
                        suba #5
                        staa BRILLO
                        bra PH_clear_and_return

PH_do_3                 ldaa BRILLO
                        cmpa #100

                        beq PH_clear_and_return

                        adda #5
                        staa BRILLO

PH_clear_and_return     movb #$00 PIEH
                        movb #100 Cont_Reb
                        movb #$FF Tecla
                        movb #$FF Tecla_in
                        bclr Banderas,$01

PH_return               rti

;; ==================== Subrutina TC4_ISR ==================================== 

TC4_ISR                 ldd TCNT
                        addd #14
                        std TC4

                        tst Cont_Delay
                        beq TC4_MUX

                        dec Cont_Delay

TC4_MUX                 ldaa CONT_TICKS
                        cmpa #N

                        beq TC4_inc_cont_dig

                        inc CONT_TICKS

                        bra TC4_calc_dt

TC4_inc_cont_dig        clr CONT_TICKS
                        inc CONT_DIG

                        ldaa CONT_DIG
                        cmpa #5

                        beq TC4_clr_cont_dig

                        bra TC4_calc_dt

TC4_clr_cont_dig        clr CONT_DIG

TC4_calc_dt             ldaa #100
                        suba BRILLO
                        ldab #N
                        mul
                        ldx #100
                        idiv 
                        tfr x,b

                        ldaa #N
                        sba
                        staa DT

                        tst CONT_TICKS
                        beq TC4_load_val

TC4_check_dt            ldaa CONT_TICKS
                        cmpa DT

                        beq TC4_clean_val

                        bra TC4_DEC_Cont7seg

TC4_load_val            ldaa CONT_DIG
                        
                        cmpa #0
                        beq TC4_ld_0

                        cmpa #1
                        beq TC4_ld_1

                        cmpa #2
                        beq TC4_ld_2

                        cmpa #3
                        beq TC4_ld_3

                        cmpa #4
                        beq TC4_ld_4

                        bra TC4_check_dt

TC4_ld_0                movb #$0E PTP
                        bset PTJ,$02
                        movb DISP1 PORTB

                        bra TC4_check_dt

TC4_ld_1                movb #$0D PTP
                        movb DISP2 PORTB

                        bra TC4_check_dt

TC4_ld_2                movb #$0B PTP
                        movb DISP3 PORTB 

                        bra TC4_check_dt

TC4_ld_3                movb #$07 PTP 
                        movb DISP4 PORTB 

                        bra TC4_check_dt

TC4_ld_4                movb #$0F PTP
                        bclr PTJ,$02
                        movb LEDS PORTB 

                        bra TC4_check_dt                                                                        

TC4_clean_val           bset PTJ,$02
                        movb #$0F PTP

TC4_DEC_Cont7seg        dec CONT_7SEG
                        tst CONT_7SEG
                        beq TC4_7seg

                        bra TC4_Retornar

TC4_7seg                jsr BCD_7SEG

                        movb #5000 CONT_7SEG                        

TC4_Retornar            rti