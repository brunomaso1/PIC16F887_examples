; PIC16F887 Configuration Bit Settings
; Assembly source line config statements
#include "p16f887.inc"
    
; Bits de configuracion

; CONFIG1
; __config 0xE0C2
 __CONFIG _CONFIG1, _FOSC_HS & _WDTE_OFF & _PWRTE_ON & _MCLRE_OFF & _CP_OFF & _CPD_OFF & _BOREN_OFF & _IESO_OFF & _FCMEN_OFF & _LVP_OFF
; CONFIG2
; __config 0xFEFF
 __CONFIG _CONFIG2, _BOR4V_BOR21V & _WRT_OFF

; Organizacion de la memoria EEPROM.
; 0x30 -> Flag que indica si está¡ usado el buffer o no.
; 0x31 -> Puntero actual del buffer.
; 0x40 - 0x49 -> Buffer.
    
; Organizacion de la memoria de datos 
cblock 0x20	; Comienzo a escribir la memoria de datos en la direccion 0x20
; Definicion de variables
    
    W_TEMP ; 0X20
    STATUS_TEMP ; 0X21
    CONTADOR_1 ; 0x22
    CONTADOR_2 ; 0x23
    CONTADOR_3 ;0x24
    VALOR_CONVERSION_TEMP ; 0x25
    VALOR_CONVERSION ; 0x26
    VALOR_CONVERSIONH ; 0x27
    VALOR_CONVERSIONL ; 0x28
    VALOR_CONVERSION_MEMORIA ; 0x29
    CONTADOR_TIMER1 ; 0x2A
    SIGUIENTE_PUNTERO ; 0X2B
    PUNTERO_ACTUAL ; 0x2C
    TEMP_W ; 0x2D
    STATUS_TEMP_CASE ; 0x2E
    W_TEMP_CASE ; 0x2F
    ITERADOR ; 0x30
    DELAY_CONTADOR ; 0x31
    DELAY_1MS_CONTADOR_1 ; 0x32
    DELAY_1MS_CONTADOR_2 ; 0x33
    MULTIPLICANDO_REGLA ; 0x34
    DIVISOR_REGLA ; 0x35
    REGLAE ; 0x36
    REGLAF ; 0x37
    VALOR_CONVERSION_REGLA ; 0x38
    MULTIPLICANDO ; 0x39
    PRODH ; 0x3A
    PRODL ; 0x3B
    COCIENTE ; 0x3C
    RESTO ; 0x3D
    MULT ; 0x3E
    DIVIDENDO ; 0x3F
    ASCII1 ; 0x40
    ASCII2 ; 0x41
    ASCII3 ; 0x42
    ASCII_TEMP ; 0x43
    ASCII_CONVERSION ; 0x44
    
    ROJO
    AZUL
    VERDE
    AMARILLO
    VALOR_RGB
    CONTADOR_RGB
    RGB_W_TEMP
    
endc
   
;Organizacion de la memoria de programacion
org 0x0000
goto main

org 0x0004
goto interrupt

;;;;;;;;;;;;;;;;;;;;;;;;;;;;; PROGRAMA PRINCIPAL ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        
main
    call configuracion_inicial
    
mainloop
    call realizar_conversion
;    call encender_rgb_1
;    call encender_rgb_2
    call encender_rgb_3
    goto mainloop
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;; RUTINA DE INTERRUPCION ;;;;;;;;;;;;;;;;;;;;;;;;;;

interrupt
    call guardar_contexto
    
    call cargar_contexto
    retfie ; interrupt
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;; CONFIGURACION INICIAL ;;;;;;;;;;;;;;;;;;;;;;;;;;;

configuracion_inicial
    ; Configuro las luces RGB.
    banksel TRISC
    clrf TRISC
    banksel PORTC
    clrf PORTC    
    
    ; Configuro las entradas de voltaje analogicas (PUERTOA).
    banksel TRISA
    bsf TRISA, 0 ; Seteo RA0 como entrada (perilla analogica)
    bsf TRISA, 1 ; Seteo RA1 como entrada (perilla analógica)
    banksel ANSEL
    bsf ANSEL, 0 ; Seto el puerto RA0 como analogico.
    bsf ANSEL, 1 ; Seto el puerto RA1 como analogico.

    ; Configuracion de la conversión analógica.
    banksel ADRESH
    clrf ADRESH
    banksel ADRESL
    clrf ADRESL
    banksel ADCON1
    clrf ADCON1 ; ADFM = Left justified | VCFG1 = Vss | VCFG0 = Vdd	
    ; Configuración del reloj y encendido del conversor analogico.
    banksel ADCON0 
    movlw b'10000001'
    movwf ADCON0 ; ADCS = Fosc/32 (TAD: 1.6(x10^-6)s) | ADON = ADC is enabled.

    ; Configuro las interrupciones.
    bsf INTCON, GIE ; Global interrupt enable bit.
    bsf INTCON, PEIE ; Pheripheral interrupt enable bit.

    return ; configurar_puertos

;;;;;;;;;;;;;;;;;;;;;;;;;;;;; RUTINAS PROGRAMA PRINCIPAL ;;;;;;;;;;;;;;;;;;;;;;

encender_rgb_1
    banksel VALOR_CONVERSION
    movf VALOR_CONVERSION, w
    movwf VALOR_RGB
    movlw d'85'
    subwf VALOR_RGB, f
    ; INICIO IF
	btfsc STATUS, C
	; THEN (85 < VALOR_RGB)
	goto $+2
	; ELSE (85 > VALOR_RGB)
	goto encender_unicamente_verde
	movlw d'85'
	subwf VALOR_RGB, f
	; INICIO IF
	    btfsc STATUS, C
	    ; THEN (170 > VALOR_RGB)
	    goto encender_unicamente_rojo
	    ; ELSE (170 < VALOR_RGB)
	    goto encender_unicamente_azul	    
	; FIN IF
    ; FIN IF

    return ; encender_rgb
    
encender_rgb_2
    banksel VALOR_CONVERSION
    movf VALOR_CONVERSION, w
    movwf VALOR_RGB
    movlw d'85'
    subwf VALOR_RGB, f
    ; INICIO IF
	btfsc STATUS, C
	; THEN (85 < VALOR_RGB)
	goto $+2
	; ELSE (85 > VALOR_RGB)
	goto encender_unicamente_verde
	movlw d'85'
	subwf VALOR_RGB, f
	; INICIO IF
	    btfsc STATUS, C
	    ; THEN (170 > VALOR_RGB)
	    goto encender_unicamente_rojo
	    ; ELSE (170 < VALOR_RGB)
	    goto encender_unicamente_amarillo	    
	; FIN IF
    ; FIN IF

    return ; encender_rgb
    
encender_rgb_3
    ; Calculo los valores de ROJO, VERDE y AZUL.
    call obtener_rgb    
    call parpadear_luces_rgb
    return ; encender_rgb_3

obtener_rgb
;    w*MULTIPLICANDO_REGLA/DIVISOR_REGLA;
    banksel MULTIPLICANDO_REGLA
    movlw d'100'
    movwf MULTIPLICANDO_REGLA
    movlw d'128'
    movwf DIVISOR_REGLA
    
    banksel VALOR_RGB
    movf VALOR_CONVERSION, w
    movwf VALOR_RGB
    
    ; Obtengo el valor del verde:
    sublw d'128'
    btfss STATUS, C
    goto $+11
    movf VALOR_RGB, w
    call regla_de_tres
    movf REGLAE, w
    movwf VERDE 
    movlw d'100'
    movwf RGB_W_TEMP
    movf VERDE, w
    subwf RGB_W_TEMP, w
    movwf VERDE
    goto $+2
    clrf VERDE
    
    ; Obtengo el valor del azul.
    banksel AZUL
    movf VALOR_RGB, w
    call regla_de_tres
    movf REGLAE, w
    movwf AZUL
    sublw d'100'
    btfsc STATUS, C
    goto $+6   
    movlw d'200'
    movwf RGB_W_TEMP
    movf AZUL, w
    subwf RGB_W_TEMP, w
    movwf AZUL
    
    ; Obtengo el valor del rojo.
    movf VALOR_RGB, w
    sublw d'128'
    btfsc STATUS, C
    goto $+14
    movlw d'255'
    movwf RGB_W_TEMP
    movf VALOR_RGB, w
    subwf RGB_W_TEMP, w
    call regla_de_tres
    movf REGLAE, w
    movwf ROJO
    movlw d'100'
    movwf RGB_W_TEMP
    movf ROJO, w
    subwf RGB_W_TEMP, w
    movwf ROJO
    goto $+2
    clrf ROJO

    return ; obtener_rgb
    
parpadear_luces_rgb
    banksel ROJO
    movf ROJO, w
    btfsc STATUS, Z
    goto $+3
    call encender_unicamente_rojo
    call esperar
    
    banksel VERDE
    movf VERDE, w
    btfsc STATUS, Z
    goto $+3
    call encender_unicamente_verde
    call esperar
    
    banksel AZUL
    movf AZUL, w
    btfsc STATUS, Z
    goto $+3
    call encender_unicamente_azul
    call esperar
    
    return ; parpadear_luces_rgb
    
esperar
    banksel CONTADOR_RGB
    movwf CONTADOR_RGB
    decfsz CONTADOR_RGB, f
    goto $-1
    return ; esperar
    
encender_unicamente_verde
    bsf PORTC, 3 ; Verde
    bcf PORTC, 2 ; Rojo
    bcf PORTC, 1 ; Azul
    return ; encender_unicamente_verde
    
encender_unicamente_rojo
    bcf PORTC, 3 ; Verde
    bsf PORTC, 2 ; Rojo
    bcf PORTC, 1 ; Azul
    return ; encender_unicamente_rojo
    
encender_unicamente_azul
    bcf PORTC, 3 ; Verde
    bcf PORTC, 2 ; Rojo
    bsf PORTC, 1 ; Azul
    return ; encender_unicamente_azul
    
encender_unicamente_amarillo
    banksel ROJO
    movlw d'150'
    movwf ROJO
    movlw d'1'
    movwf VERDE
    movlw d'0'
    movwf AZUL
    
    call parpadear_luces_rgb
    return ; encender_unicamente_amarillo
    
; Realiza una regla de tres.
; w = w*MULTIPLICANDO_REGLA/DIVISOR_REGLA
regla_de_tres
    banksel VALOR_CONVERSION_REGLA
    movwf VALOR_CONVERSION_REGLA
    movf MULTIPLICANDO_REGLA, w
    movwf MULTIPLICANDO
    movf VALOR_CONVERSION_REGLA, w
    call multiplicar
    
    ; Si la multiplicación dio 0, devuelvo 0.
    banksel PRODH
    movf PRODH, f
    ; INICIO IF
	btfss STATUS, Z
	; THEN (PRODH <> 0)
	goto $+7
	; ELSE (PRODH = 0)
	banksel PRODL
	movf PRODL, f
	; INICIO IF
	    btfss STATUS, Z
	    ; THEN (PRODL <> 0)
	    goto $+2
	    ; ELSE (PRODL = 0)
	    retlw 0 ; Si es 0 el producto, devuelvo 0 porque no puedo dividir.
	; FIN IF
    ; FIN IF
    
    ; LOS PARAMETROS DE dividir YA ESTAN CARGADOS, CARGO SOLO w.
    banksel DIVISOR_REGLA
    movf DIVISOR_REGLA, w
    call dividir
    
    banksel COCIENTE
    movf COCIENTE, w
    movwf REGLAE
    movf RESTO, w
    movwf REGLAF    
    
    return ; regla_de_tres

; Multiplica dos numeros.
; MULTIPLICANDO * w = PRODH:PRODL
multiplicar
    banksel MULT
    movwf MULT
    
    ; Limpio los resultados.
    banksel PRODL
    clrf PRODL
    clrf PRODH
    
    banksel MULTIPLICANDO
    movf MULTIPLICANDO, f
    ; INICIO IF
	btfsc STATUS, Z
	; THEN (MULTIPLICANDO = 0)
	return
	; ELSE (MULTIPLICANDO <> 0)
	multiplicar_loop
	    banksel MULT
	    movf MULT, w
	    banksel PRODL
	    addwf PRODL, f
	    btfsc STATUS, C
	    incf PRODH, f
	    decfsz MULTIPLICANDO, f
	    goto multiplicar_loop	    
    ; FIN IF
    return ; multiplicar

; Divide dos numeros.
; PRODH:PRODL/w = w*COCIENTE + RESTO
dividir
    banksel COCIENTE
    clrf COCIENTE
    clrf RESTO
    movwf DIVIDENDO
    
    loop_dividir
	banksel PRODH
	movf PRODH, f
	; INICIO IF
	    btfss STATUS, Z
	    ; THEN (PRODH <> 0)
	    goto restar_dividir
	    ; ELSE (PRODH = 0)
	    movf DIVIDENDO, w
	    subwf PRODL, w
	    ; INICIO IF
		btfsc STATUS, C
		; THEN (PRODL >= DIVIDENDO)
		goto restar_dividir
		; ELSE (PRODL < DIVIDENDO)
		movf PRODL, w
		movwf RESTO
		return ; dividir
	    ; FIN IF
	; FIN IF
	
	restar_dividir
	    banksel COCIENTE
	    incf COCIENTE, f
	    
	    movf DIVIDENDO, w
	    subwf PRODL, f
	    ; INICIO IF
		btfsc STATUS, C
		; THEN (PRODL < DIVIDENDO)
		goto $+2
		; ELSE (PRODL >= DIVIDENDO)
		decf PRODH, f
	    goto loop_dividir
    
; Realiza la conversion y almacena los valores en variables.
realizar_conversion
    bsf ADCON0, GO ; Start conversion
    btfsc ADCON0, GO ; Is conversion done?
    goto $-1 ; No, test again
	
    ; Obtener el valor de la conversión.
    banksel ADRESH
    movf ADRESH, w
    banksel VALOR_CONVERSION
    movwf VALOR_CONVERSION
	
    return ; realizar_conversion

; Rutinas de contexto.
guardar_contexto
    banksel W_TEMP
    movwf W_TEMP  ; Guardo w.
    swapf STATUS, w ; Swap status en w.
    movwf STATUS_TEMP ; Guardo STATUS.
    return ; guardar_contexto
	
cargar_contexto
    banksel STATUS_TEMP
    swapf STATUS_TEMP, w
    movwf STATUS
    swapf W_TEMP, f
    swapf W_TEMP, w
    return ; cargar_contexto
	
end