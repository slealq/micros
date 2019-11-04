#include registers.inc

; DECLARACION DE ESTRUCTURAS DE DATOS
                org         $1000
LEDS:           ds      1
CONT_OC1:       ds      1           	;; Cuenta de 0 -> 100
CONT_OC2:       ds      1               ;; Cuenta de 0 -> 100
CONT_OC3        ds      1               ;; Cuenta de 0 -> 5
                org     $3E66
                dw      OC_ISR


; INSTRUCCIONES
                org     $2000
                movb    #$FF DDRB
                bset    DDRJ,$02
                bclr    PTJ,$02
                movb    #$0F DDRP
                bset    PTP,$0F

                movb    #100,CONT_OC1
                movb    #100,CONT_OC2
                movb    #5,CONT_OC3

                movb    #$90 TSCR1 
                movb    #$05 TSCR2 
                movb    #$10 TIOS 
                movb    #$00 TCTL1 
                movb    #$00 TCTL2 
                movb    #$10 TIE 

                lds     #$3BFF
                cli                

                ldd     TCNT
                addd    #15
                std     TC4

                movb    #$01,LEDS

ESPERE          bra     *

OC_ISR          ldd     TCNT
                addd    #15
                std     TC4

                dec     CONT_OC1
                tst     CONT_OC1
                beq     CONTINUAR
                bra     RETORNAR

CONTINUAR       movb    #100,CONT_OC1
                dec     CONT_OC2
                tst     CONT_OC2
                beq     CONTINUAR_5
                bra     RETORNAR

CONTINUAR_5     movb    #100,CONT_OC2
                dec     CONT_OC3
                tst     CONT_OC3
                beq     LEDS_SET
                bra     RETORNAR                
                
LEDS_SET        movb    #5,CONT_OC3
                movb    LEDS,PORTB
                lsl     LEDS
                tst     LEDS
                beq     REINICIAR

RETORNAR        rti

REINICIAR       movb    #$01,LEDS
                bra     RETORNAR