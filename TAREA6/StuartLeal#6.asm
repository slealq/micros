;; ===========================================================================
;; Autor: Stuart Leal Q
;; Fecha: 17 de Noviembre de 2019
;; Version: 1.0
;; ===========================================================================

#include registers.inc

;; ===========================================================================
;; ==================== DECLARACION DE ESTRUCTURAS DE DATOS ==================
;; ===========================================================================

MAX_TANQUE:             EQU 30
AREA100:                EQU 1963
EOL:                    EQU 4
LF:                     EQU 10
CR:                     EQU 13
BS:                     EQU 8
SPC:                    EQU 32

                        org $1010
NIVEL_PROM:             ds 2
NIVEL:                  ds 1
VOLUMEN:                ds 2
CONT_OC:                ds 1

POS:                    ds 2
TEMP:                   ds 2
ESTADO:                 ds 1
SECUENCIA:              ds 1

ENCABEZADO:             fcc 'MEDICION DE VOLUMEN'
                        db LF,CR,EOL

VOLUMEN_MSG:            fcc 'VOLUMEN ACTUAL: '
VOLUMEN_VAL:            ds 3
                        db LF,CR,EOL
                        ;; son 19 caracteres para borrar todo el mensaje
                        ;; de volumen_msg
VOLUMEN_MSG_DEL:        db BS,CR,SPC,SPC,SPC,SPC,SPC,SPC,SPC,SPC,SPC,SPC,SPC
                        db SPC,SPC,SPC,SPC,SPC,SPC,SPC,SPC,CR,EOL

ALERTA_BAJO:            fcc 'Alarma: El Nivel esta Bajo'
                        db LF,CR,EOL
                        ;; son 26 caracteres para borrar el msg de alarma bajo
ALERTA_BAJO_DEL:        db BS,CR,SPC,SPC,SPC,SPC,SPC,SPC,SPC,SPC,SPC,SPC,SPC
                        db SPC,SPC,SPC,SPC,SPC,SPC,SPC,SPC,SPC,SPC,SPC,SPC
                        db SPC,SPC,SPC,CR,EOL

ALERTA_ALTA:            fcc 'Tanque lleno, Bomba Apagada'
                        db LF,CR,EOL
                        ;; son 27 caracteres para borrar el msg de alarma bajo
ALERTA_ALTA_DEL:        db BS,CR,SPC,SPC,SPC,SPC,SPC,SPC,SPC,SPC,SPC,SPC,SPC
                        db SPC,SPC,SPC,SPC,SPC,SPC,SPC,SPC,SPC,SPC,SPC,SPC
                        db SPC,SPC,SPC,SPC,CR,EOL                        

;; ===========================================================================
;; ==================== DECLARACION DE INTERRUPCIONES ========================
;; ===========================================================================

                        org $3E52
                        dw ATD0_ISR        

                        org $3E54
                        dw SCI1_ISR   

                        org $3E64
                        dw OC5_ISR      

;; ===========================================================================
;; ==================== CODIFICACION HARDWARE ================================
;; ===========================================================================

                        org $2000
                        lds #$3bff

                        ;; config para ATD0
Main                    ldab 200
                        movb #$82 ATD0CTL2

MN_wait_10us            decb
                        cmpb #0
                        beq MN_After_10us

                        bra MN_wait_10us

MN_After_10us           movb #$30 ATD0CTL3
                        movb #$10 ATD0CTL4
                        movb #$87 ATD0CTL5

                        ;; config para SC1
                        movw #39 SC1BDH
                        movb #$12 SC1CR1
                        movb #$08 SC1CR2

                        ;; config para OC5
                        movb #$90 TSCR1
                        movb #$06 TSCR2
                        movb #$20 TIOS
                        movb #$00 TCTL1
                        movb #$00 TCTL2
                        movb #$20 TIE
 
                        ;; habilitar rele
                        bset DDRE,$04

                        cli                        

;; ===========================================================================
;; ==================== INICIALIZACIÓN ESTRUCTURAS ===========================
;; ===========================================================================


;; ===========================================================================
;; ==================== PROGRAMA PRINCIPAL ===================================
;; ===========================================================================

                        movb #1 ESTADO
                        clr SECUENCIA
 
                        ;; escribir encabezado y msg primera vez
                        movw #ENCABEZADO POS
                        jsr SMB

                        jsr SET_VOL
                        movw #VOLUMEN_MSG POS
                        jsr SMB                        
                        ;; seguir haciendo los calculos de vol y metros

MN_fin                  jsr CALCULO
                        bra MN_fin                        

;; ==================== Subrutina ATD0_ISR ===================================

ATD0_ISR                ldd ADR00H
                        addd ADR01H
                        addd ADR02H
                        addd ADR03H
                        addd ADR04H
                        addd ADR05H
                        ldx #6
                        idiv
                        stx NIVEL_PROM
                        movb #$87 ATD0CTL5

                        rti

;; ==================== Subrutina CALCULO ====================================

CALCULO                 ldd NIVEL_PROM
                        ldy #MAX_TANQUE
                        emul
                        ldx #$3ff
                        ediv

                        cpd #500
                        blo CALCULO_nivel_clamp

                        iny

CALCULO_nivel_clamp     cpy #25
                        bls CALCULO_store_nivel

                        ldy #25

CALCULO_store_nivel     tfr y,a
                        staa NIVEL
                        ldd #AREA100
                        emul
                        ldx #100
                        idiv 

                        cpd #50
                        blo CALCULO_sv_volumen

                        inx

CALCULO_sv_volumen      stx VOLUMEN                       
                        
                        rts

;; ==================== Subrutina SCI1_ISR ====================================

SCI1_ISR                ldx POS
                        ldaa 1,x+
                        stx POS

                        cmpa #EOL
                        beq SCI1_disable

                        ldab SC1SR1
                        staa SC1DRL                      

                        bra SC1_return

SCI1_disable            bclr SC1CR2,$40

SC1_return              rti                        

;; ==================== Subrutina OC5_ISR =====================================

OC5_ISR                 ldd TCNT 
                        addd #37500
                        std TC5

                        tst CONT_OC
                        beq OC5_ld_msg_vars

                        dec CONT_OC
                        bra OC5_return 

OC5_ld_msg_vars         jsr MSG_CONTROL

                        movb #10 CONT_OC  

OC5_return              rti                        

;; ==================== Subrutina MSG_CONTROL =================================

MSG_CONTROL             cli ;; hay que habilitar interrupciones para SCI

                        ldaa ESTADO

                        cmpa #0
                        beq MC_st_0

                        cmpa #1
                        beq MC_st_1

                        ;; bloque de comparación para ESTADO = 2 | INICIO
                        ldd VOLUMEN
                        cpd #442
                        blo MC_chk_st_2

                        ldab SECUENCIA
                        cmpb #2
                        beq MC_st2_clr_sec
                        
                        cmpb #0
                        beq MC_st2_inc_sec
                        bra MC_perform_action

MC_st2_clr_sec          clr SECUENCIA
                        bra MC_perform_action

MC_st2_inc_sec          inc SECUENCIA
                        bra MC_perform_action

MC_chk_st_2             ldab SECUENCIA
                        cmpb #2
                        beq MC_st2_ch_st

                        movb #2 SECUENCIA
                        bra MC_perform_action

MC_st2_ch_st            movb #1 ESTADO
                        clr SECUENCIA
                        bra MC_perform_action      
                        ;; bloque de comparación para ESTADO = 2 | FIN

                        ;; bloque de comparación para ESTADO = 0 | INICIO
MC_st_0                 ldd VOLUMEN
                        cpd #147
                        bhi MC_chk_st_0      

                        ldab SECUENCIA
                        cmpb #2
                        beq MC_st0_clr_sec
                        
                        cmpb #0
                        beq MC_st0_inc_sec
                        bra MC_perform_action

MC_st0_clr_sec          clr SECUENCIA
                        bra MC_perform_action

MC_st0_inc_sec          inc SECUENCIA
                        bra MC_perform_action

MC_chk_st_0             ldab SECUENCIA
                        cmpb #2
                        beq MC_st0_ch_st

                        movb #2 SECUENCIA
                        bra MC_perform_action

MC_st0_ch_st            movb #1 ESTADO
                        clr SECUENCIA
                        bra MC_perform_action    
                        ;; bloque de comparación para ESTADO = 0 | FIN

                        ;; bloque de comparación para ESTADO = 1 | INICIO

MC_st_1                 ldd VOLUMEN
                        cpd #74
                        bls MC_st1_2_st0

                        cpd #442
                        bhs MC_st1_2_st2

                        bra MC_perform_action

MC_st1_2_st0            clr ESTADO
                        clr SECUENCIA
                        bra MC_perform_action

MC_st1_2_st2            movb #2 ESTADO
                        clr SECUENCIA
                        ;; bloque de comparación para ESTADO = 1 | FIN


                        ;; comienza P1A -> Acciones de borrar e imprimir
MC_perform_action       ldaa ESTADO
                        cmpa #0
                        beq MC_aler_baja_chk_del

                        cmpa #2
                        beq MC_aler_alt_chk_del

                        bra MC_rm_msg

MC_aler_baja_chk_del    tst SECUENCIA
                        bne MC_aler_baja_del
                        bra MC_rm_msg

MC_aler_baja_del        movw #ALERTA_BAJO_DEL POS
                        jsr SMB
                        bra MC_rm_msg

MC_aler_alt_chk_del     tst SECUENCIA
                        bne MC_aler_alta_del
                        bra MC_rm_msg

MC_aler_alta_del        movw #ALERTA_ALTA_DEL POS
                        jsr SMB

                        ;; lo siguiente siempre debería ejecutarse,
                        ;; sin importar cuál es el estado
MC_rm_msg               movw #VOLUMEN_MSG_DEL POS
                        jsr SMB

                        jsr SET_VOL
                        movw #VOLUMEN_MSG POS
                        jsr SMB

                        ;; ahora hay que ver si hay que imprimir alguna
                        ;; alerta
                        ldaa ESTADO
                        cmpa #0
                        beq MC_aler_baja_chk

                        cmpa #2
                        beq MC_aler_alt_chk

                        bra MC_retornar

MC_aler_baja_chk        ldab SECUENCIA
                        cmpb #2
                        bne MC_aler_baja
                        bra MC_retornar

MC_aler_baja            movw #ALERTA_BAJO POS
                        jsr SMB
                        bra MC_retornar

MC_aler_alt_chk         ldab SECUENCIA
                        cmpb #2
                        bne MC_aler_alta

                        ;; encender bomba !
                        bset PORTE,$04
                        bra MC_retornar

MC_aler_alta            movw #ALERTA_ALTA POS
                        jsr SMB

                        tst SECUENCIA
                        bne MC_retornar

                        ;; apagar bomba !
                        bclr PORTE,$04

MC_retornar             rts

;; ==================== Subrutina SET_VOL =====================================

SET_VOL                 ldd VOLUMEN ;; calcular centenas
                        ldx #100
                        idiv 
                        tfr x,d

                        stab VOLUMEN_VAL ;; guardar en primer valor
                        bset VOLUMEN_VAL,$30 ;; y sumar $30

                        ldy #100 ;; restar centenas*100
                        emul
                        std TEMP
                        ldd VOLUMEN
                        subd TEMP
                        tfr d,y
                        ldx #10 ;; calcular decenas
                        idiv
                        tfr x,b
                        
                        stab VOLUMEN_VAL+1 ;; guardar en segundo valor
                        bset VOLUMEN_VAL+1,$30 ;; sumar $30

                        ldaa #10 ;; restar decenas*10 a Volumen sin centenas
                        mul
                        std TEMP
                        tfr y,d
                        subd TEMP

                        stab VOLUMEN_VAL+2 ;; guardar unidades
                        bset VOLUMEN_VAL+2,$30 ;; sumar $30

                        rts

;; ==================== Subrutina SMB ========================================
                        
                        ;; Subrutina SendMessageBlocking
                        ;; Envía un string por puerto serial
                        ;; y se espera hasta que se envíe completo

SMB                     bset SC1CR2,$40

SMB_wait_send           brclr SC1CR2,$40,SMB_return
                        bra SMB_wait_send

SMB_return              rts                        