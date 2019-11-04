#include registers.inc

; DECLARACION DE ESTRUCTURAS DE DATOS



; INSTRUCCIONES
        org $2000
        clr DDRH
        movb #$FF DDRB
        bset DDRJ,$02
        bclr PTJ,$02
        movb #$0F DDRP
        movb #$0F PTP
        
init    ldaa PTIH
        staa PORTB
        
        bra init