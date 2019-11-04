;; ===========================================================================
;; ==================== DECLARACION DE ESTRUCTURAS DE DATOS ==================
;; ===========================================================================

                        org $1000
LONG:                   db 16
CANT:                   ds 1
CONT:                   ds 1
CUAD_LONG:              db 16

                        org $1020
DATOS:                  db 4,9,18,4,49,63,144,225,36,15,100,196,5,6,81,64

                        org $1040
CUAD:                   db 0,1,4,9,16,25,36,49,64,81,100,121,144,169,196,225

                        org $1100
ENTERO:                 ds LONG         ;; pueden ser HASTA LONG valores

;; ==================== DECLARACION PARA LEER_CANT ===========================

                        org $1200

DIG_COUNTER:            ds 1            ;; entero variable sin signo
BCD_H:                  ds 1            ;; entero variable sin signo
BCD_L:                  ds 1            ;; entero variable sin signo

FIN_CHAR:               equ $0
CR:                     equ $0D
LF:                     equ $0A

IN_MSG:                 fcc '> INGRESE EL VALOR DE CANT (ENTRE 1 Y 99): '
                        db FIN_CHAR

;; ==================== DECLARACION PARA RAIZ ================================                        

RAIZ_IN                 ds 1                        

;; ==================== DECLARACION PARA BUSCAR ==============================

IDX_DATOS               ds 1
IDX_CUAD                ds 1   

;; ==================== DECLARACION PARA PRINT_RESULT ========================

CONT_MSG:               fcc '> CANTIDAD DE VALORES ENCONTRADOS: %u'
                        db FIN_CHAR

ENTEROS_MSG:            fcc '> ENTERO: '
                        db FIN_CHAR

COMMA:                  db ','

UINT:                   fcc '%u'
                        db FIN_CHAR

ESPACIO:                db CR,LF,CR,LF,FIN_CHAR

CONTADOR:               ds 1

;; ==================== DECLARACION PARA DEBUG12 =============================

GETCHAR:                equ $EE84
PUTCHAR:                equ $EE86
PRINTF:                 equ $EE88

;; ===========================================================================
;; ==================== INICIO DE CODIFICACION ===============================
;; ===========================================================================

                        org $2000
                        lds #$3bff
                        
                        jsr leer_cant           ;; ir a pedir dato

                        jsr buscar

                        jsr print_result

fin                     bra *

;; ==================== SUBRUTINA LEER_CANT ===================================

leer_cant               ldx #$0000
                        ldd #IN_MSG

                        jsr [PRINTF,x]
                        
                        clr DIG_COUNTER
                        
get_input_char          ldx #$0000

                        jsr [GETCHAR,x]

                        cmpb #$30
                        blo get_input_char
                        
                        cmpb #$39
                        bhi get_input_char
                        
                        tst DIG_COUNTER        ;; dig_counter != 0
                        bne verif_dig_counter_1

                        stab BCD_H              ;; bcd_h <- R2
                        bra inc_dig_counter

verif_dig_counter_1     ldaa BCD_H              ;; bcd_h != $30/>
                        cmpa #$30
                        bne guardar_bcd_l

                        cmpb #$30               ;; R2 == 0
                        beq get_input_char
                        
guardar_bcd_l           stab BCD_L              ;; bcd_l <- R2
                        
inc_dig_counter         inc dig_counter
                        jsr [PUTCHAR,x]

                        ldaa dig_counter        ;; dig_counter = 2 ?
                        cmpa #$02
                        bne get_input_char

leer_cant_retorno       ldaa BCD_H              ;; CANT =
                        suba #$30               ;; (BCD_H-$30)*10+ BCD_L - $30
                        ldab #$0a
                        mul
                        ldaa BCD_L
                        suba #$30
                        aba
                        staa CANT
                        
                        rts

;; ==================== SUBRUTINA RAIZ ========================================
                        
raiz                    leas 2,SP
                        
                        pula

                        staa RAIZ_IN    
                        clrb

while_diff              cba
                        beq raiz_regresar
                        
                        tfr a,y
                        clra
                        ldab RAIZ_IN
                        tfr y,x
                        idiv
                        tfr y,b
                        abx
                        tfr x,d
                        lsrd    
                        tfr d,a
                        tfr y,b

                        bra while_diff
                        
raiz_regresar           psha

                        leas 0-2,SP

                        rts                        

;; ==================== SUBRUTINA BUSCAR ======================================

buscar                  clr IDX_DATOS
                        clr IDX_CUAD
                        clr CONT

verif_idx_datos         ldaa IDX_DATOS
                        cmpa LONG
                        beq fin_buscar

                        ldx #DATOS
                        ldaa a,x                ;; a = (IDX_DATOS + DATOS)

verif_idx_cuad          ldab IDX_CUAD
                        cmpb CUAD_LONG
                        beq inc_idx_datos

                        ldx #CUAD
                        ldab b,x                ;; b = (IDX_CUAD + CUAD)                        

                        cba
                        beq calc_raiz

                        inc IDX_CUAD
                        bra verif_idx_cuad

calc_raiz               psha
                        
                        jsr raiz
                                                
                        pula
                        ldx #ENTERO
                        ldab CONT
                        staa b,x                ;; *
                        incb
                        stab CONT

                        cmpb CANT
                        beq fin_buscar

inc_idx_datos           inc IDX_DATOS
                        clr IDX_CUAD

                        bra verif_idx_datos                    

fin_buscar              rts                        

;; ==================== SUBRUTINA PRINT_RESULT ================================

print_result            ldx #$0000
                        ldd #ESPACIO
                        jsr [PRINTF,x]

                        ldab CONT
                        clra
                        pshd
                        ldx #$0000
                        ldd #CONT_MSG                        
                        jsr [PRINTF,x]

                        ldx #$0000
                        ldd #ESPACIO
                        jsr [PRINTF,x]

                        ldx #$0000
                        ldd #ENTEROS_MSG
                        jsr [PRINTF,x]

                        clr CONTADOR

                        ldy #ENTERO
                        ldaa CONTADOR
                        ldab a,y
                        clra
                        pshd
                        ldd #UINT
                        ldx #$0000
                        jsr [PRINTF,x]                        

                        inc CONTADOR
                        ldaa CONTADOR
                        
                        cmpa CONT
                        beq imp_fin

imprimir_cont           ldab COMMA
                        ldx #$0000
                        jsr [PUTCHAR,x] 

                        ldy #ENTERO
                        ldaa CONTADOR
                        ldab a,y
                        clra
                        pshd
                        ldd #UINT
                        ldx #$0000
                        jsr [PRINTF,x]

                        inc CONTADOR
                        ldaa CONTADOR
                        
                        cmpa CONT
                        bne imprimir_cont

imp_fin                 inca
                        lsla
                        leas a,sp

                        rts

                    
