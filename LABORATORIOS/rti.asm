#include registers.inc

; DECLARACION DE ESTRUCTURAS DE DATOS
                org         $1000
LEDS:           ds      1
CONT_RTI:       ds      1
                org     $3E70
                dw      INT_RTI


; INSTRUCCIONES
                org     $2000
                movb    #$FF DDRB
                bset    DDRJ,$02
                bclr    PTJ,$02
                movb    #$0F DDRP
                bset    PTP,$0F
                movb    #$49,RTICTL
                bset    CRGINT,$80
                lds     #$3BFF
                cli
                movb    #$01,LEDS
                movb    #50,CONT_RTI
ESPERE          bra     *

INT_RTI         bset    CRGFLG,$80
                dec     CONT_RTI
                tst     CONT_RTI
                beq     CONTINUAR
                bra     RETORNAR
CONTINUAR       movb    #50,CONT_RTI
                movb    LEDS,PORTB
                lsl     LEDS
                tst     LEDS
                beq     REINICIAR
RETORNAR        rti
REINICIAR       movb    #$01,LEDS
                bra     RETORNAR