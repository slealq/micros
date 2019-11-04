
;   DECLARACIÓN DE VARIABLES

                org $1000
NEGAT_POS:      ds 1

                org $1050
DATOS:          db $10,$20,$30,$99,$54,$FF

                org $1150
MASCARAS:       db $05,$34,$0f,$13,$08,$44,$29,$FE

                org $1300
NEGAT:          ds 1000


;   INICIO DE PROGRAMA
                org $2000

                clr NEGAT_POS
                ldx #DATOS
                ldy #MASCARAS
                
init            ldaa 0,x
                cmpa #$FF
                beq post_init
                
                inx
                bra init
                
post_init       dex

check_fin       cpx #DATOS
                blt fin
                
                ldaa 0,y
                cmpa #$FE
                beq fin
                
perform_check   ldaa 1,x-
                eora 1,y+
                
                bgt check_fin
                
                pshy
                ldy #NEGAT
                ldab NEGAT_POS
                staa b,y
                inc NEGAT_POS
                puly
                bra check_fin

fin             bra *