
;; DECLARACION DE ESTRUCTURAS DE DATOS
	        org $1000
        
L:              db 14
CANT4:          ds 1
OFDA:           ds 1            ; Offset DATOS
OFDI:           ds 1            ; Offset Div4
CONTADOR:       ds 1

                org $1100
DATOS:          db $05,$34,$0f,$13,$08,$44,$29,$fe,$10,$20,$30,$99,$54,$ff

                org $1200
DIV4:           ds 14

;; INICIO DE PROGRAMA

                org $1300
                ldx #DATOS
                ldy #DIV4
                clr CANT4
                clr OFDA
                clr OFDI
                clr CONTADOR
                
check_fin       ldaa CONTADOR
                cmpa L
                beq fin
                
                ldab OFDA
                ldaa b,x
                anda #$03                 ; si los dos msb son 0, divisible
                
                bne contadores            ; check (R1) == 0
                
                ldaa OFDI
                movb b,x a,y
                inc CANT4
                inc OFDI
                
contadores      inc OFDA
                inc CONTADOR
                bra check_fin
                
fin             bra *