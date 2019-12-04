;; ===========================================================================
;; Autor: Stuart Leal Q
;; Fecha: 12 de Noviembre de 2019
;; Version: 1.0
;; ===========================================================================

#include registers.inc

;; ===========================================================================
;; ==================== DECLARACION DE ESTRUCTURAS DE DATOS ==================
;; ===========================================================================

                        org $1000

CONT_DA                 ds 2

;; ===========================================================================
;; ==================== DECLARACION DE INTERRUPCIONES ========================
;; ===========================================================================

                        org $3E70
                        dw RTI_ISR

;; ===========================================================================
;; ==================== CODIFICACION HARDWARE ================================
;; ===========================================================================

                        org $2000

Main                    movb #$49 RTICTL
                        movb #$80 CRGINT

                        movb #$50 SPI0CR1
                        clr SPI0CR2
                        movb #$45 SPI0BR        ;; 75khz -> 75kbit/s

                        bset DDRM,$40
                        bset PTM,$40

                        movb #$FF DDRB
                        bclr PORTB,$02
                        bset DDRJ,$02
                        bclr PTJ,$02    

                        bset PORTB,$80

                        lds #$3bff
                        cli

                        movw #$00 CONT_DA

MN_fin                  bra *                        

;; ==================== Subrutina RTI_ISR ====================================

RTI_ISR                 ldx CONT_DA
                        inx
                        stx CONT_DA

                        cpx #1024

                        beq RTI_clr_contda

                        bra RTI_clr_6

RTI_clr_contda          movw #$00 CONT_DA
                        ldaa PORTB
                        eora #$01
                        staa PORTB

RTI_clr_6               bclr PTM,$40        ;; Slave select = 0 (hay un negado)

RTI_chk_ef              brset SPI0SR,$20,RTI_ld_rr1     ;; Esperar bandera de Transmission empty

                        bra RTI_chk_ef

RTI_ld_rr1              ldd CONT_DA
                        lsld
                        lsld
                        anda #$0F
                        adda #$90                       ;; Agregar código 9 en nibble superior -> Load DAC A

                        staa SPI0DR                     ;; Enviar parte ALTA primero (Está en MSB first)

RTI_chk_ef_2            brset SPI0SR,$20,RTI_ld_r2      ;; Esperar a que la bandera de transmission empty se ponga

                        bra RTI_chk_ef_2

RTI_ld_r2               stab SPI0DR                     ;; Enviar la parte baja

RTI_chk_ef_3            brset SPI0SR,$20,RTI_clr_cs     ;; Esperar a que la bandera de transmission empty se ponga de nuevo

                        bra RTI_chk_ef_3

RTI_clr_cs              bset PTM,$40        ;; Slave not select = 1 (hay un negado)
                        bset CRGFLG,$80     ;; Borrar bandera de interrupt del RTI

                        rti 
