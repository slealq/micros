;; ===========================================================================
;; Autor: Stuart Leal Q
;; Fecha: 12 de Noviembre de 2019
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

                        org $1010
NIVEL_PROM:             ds 2
NIVEL:                  ds 1
VOLUMEN:                ds 2
CONT_OC:                ds 1

POS:                    ds 2
TEMP:                   ds 2

ENCABEZADO:             fcc 'MEDICION DE VOLUMEN'
                        db LF,CR,EOL

VOLUMEN_MSG:            fcc 'VOLUMEN '
                        db LF,CR
                        fcc 'ACTUAL: '
VOLUMEN_VAL:            ds 3
                        db EOL

                        ;; son 22 caracteres para borrar todo el mensaje
                         ;; de volumen_msg
VOLUMEN_MSG_DEL:        db 8,8,8,8,8,8,8,8,8,8,8
                        db 8,8,8,8,8,8,8,8,8,8,8
                        db CR,EOL

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
 

                        cli                        

;; ===========================================================================
;; ==================== INICIALIZACIÓN ESTRUCTURAS ===========================
;; ===========================================================================


;; ===========================================================================
;; ==================== PROGRAMA PRINCIPAL ===================================
;; ===========================================================================

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
                        blo CALCULO_sv_nivel

                        iny

CALCULO_sv_nivel        tfr y,a
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

                        cli

                        tst CONT_OC
                        beq OC5_ld_msg_vars

                        dec CONT_OC
                        bra OC5_return 

OC5_ld_msg_vars         jsr SET_VOL

                        movw #VOLUMEN_MSG_DEL POS
                        bset SC1CR2,$40

OC5_wait_send           brclr SC1CR2,$40,OC5_send_erase
                        bra OC5_wait_send
OC5_send_erase          movw #VOLUMEN_MSG POS
                        bset SC1CR2,$40

                        movb #10 CONT_OC

OC5_return              rti                        

;; ==================== Subrutina MSG_CONTROL =================================



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

SMD                     bset SC1CR2,$40

SMD_wait_send           brclr SC1CR2,$40,SMD_return
                        bra SMD_wait_send

SMD_return              rts                        