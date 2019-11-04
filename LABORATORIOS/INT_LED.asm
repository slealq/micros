#include registers.inc

; DECLARACION DE ESTRUCTURAS DE DATOS
                org         $1000
LEDS:           ds      1
                org     $3E4C
                dw      PTHO_ISR

; INSTRUCCIONES
                org     $2000
                movb    #$FF DDRB
                bset    DDRJ,$02
                bclr    PTJ,$02
                movb    #$0F DDRP
                bset    PTP,$0F
                bset    PIEH,$01
                lds     #$3BFF
                cli
                movb    #$01,LEDS
ESPERE          bra     *

PTHO_ISR        bset    PIFH,$01
                cli
                movb    LEDS,PORTB
                lsl     LEDS
                tst     LEDS
                beq     REINICIAR
RETORNAR        rti
REINICIAR       movb    #$01,LEDS
                bra     RETORNAR                