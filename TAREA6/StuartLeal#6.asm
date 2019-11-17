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
EOL:                    EQU 0

                        org $1010
NIVEL_PROM:             ds 2
NIVEL:                  ds 1
VOLUMEN                 ds 2     

POS:                    ds 2

TEST_MSG:               fcc 'Este es un mensaje de prueba'
                        db EOL

;; ===========================================================================
;; ==================== DECLARACION DE INTERRUPCIONES ========================
;; ===========================================================================

                        org $3E52
                        dw ATD0_ISR        

                        org $3E54
                        dw SCI1_ISR         

;; ===========================================================================
;; ==================== CODIFICACION HARDWARE ================================
;; ===========================================================================

                        org $2000
                        lds #$3bff

Main                    ldab 200
                        movb #$82 ATD0CTL2

MN_wait_10us            decb
                        cmpb #0
                        beq MN_After_10us

                        bra MN_wait_10us

MN_After_10us           movb #$30 ATD0CTL3
                        movb #$10 ATD0CTL4
                        movb #$87 ATD0CTL5

                        movw #39 SC1BDH
                        movb #$12 SC1CR1
                        movb #$08 SC1CR2

                        cli                        

;; ===========================================================================
;; ==================== INICIALIZACIÓN ESTRUCTURAS ===========================
;; ===========================================================================


;; ===========================================================================
;; ==================== PROGRAMA PRINCIPAL ===================================
;; ===========================================================================

                        movw #TEST_MSG POS
                        bset SC1CR2,$40

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

                        cmpa EOL
                        beq SCI1_disable

                        ldab SC1SR1
                        staa SC1DRL

                        bra SC1_return

SCI1_disable            bclr SC1CR2,$40

SC1_return              rti                        

