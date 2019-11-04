
;   DECLARACIÓN DE VARIABLES

            org $1000
CANT:       db 7
TEMP:       ds 1
CAMBIO:     ds 1
CUENTA:     ds 1

            org $1100
ORDENAR:    db $FE, $59, $70, $94, $FF, $59, $70
            org $1200
ORDENADOS:  ds 7


;   INICIO DE PROGRAMA
                org $1500
init            clr CUENTA
                clr CAMBIO
                ldx #ORDENAR
                ldy #ORDENAR+1

check_cuenta    ldaa CANT
                deca
                cmpa CUENTA
                beq check_cambio
                
                ldaa 0,x
                cmpa 0,y
                ble inc_indexes
                
exchange        movb 0,x TEMP
                movb 0,y 1,x+
                movb TEMP 1,y+
                inc CAMBIO
                bra count_plus
                
inc_indexes     inx
                iny

count_plus      inc CUENTA
                bra check_cuenta

check_cambio    ldaa CAMBIO
                beq swap
                bra init

swap            ldx #ORDENAR
                ldy #ORDENADOS
                clr TEMP
                clr CUENTA
                
chk_swap_fin    ldaa CANT
                deca
                cmpa CUENTA
                beq fin
                
                ldaa 0,x
                cmpa TEMP
                
                beq inc_swp_cuen
                
                staa 0,y
                iny
                
inc_swp_cuen    inx
                staa TEMP
                inc CUENTA
                bra chk_swap_fin

fin             bra *