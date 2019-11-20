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
    W_TEMP
    STATUS_TEMP
    VALOR_CONVERSION_TEMP
    VALOR_CONVERSION
    VALOR_CONVERSIONH
    VALOR_CONVERSIONL
    TEMP_W
    STATUS_TEMP_CASE
    W_TEMP_CASE
    MULTIPLICANDO
    DIVISOR
    PRODL
    PRODH
    ASCII_TEMP
    ASCII1
    ASCII2
    ASCII3
    ASCII_CONVERSION
    MULT
    MULTIPLICANDO_REGLA
    DIVISOR_REGLA
    REGLAE
    REGLAF
    VALOR_CONVERSION_REGLA
    COCIENTE
    RESTO
    DIVIDENDO

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
    goto mainloop
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;; RUTINA DE INTERRUPCION ;;;;;;;;;;;;;;;;;;;;;;;;;;

interrupt
    call guardar_contexto

    banksel PIR1
    btfsc PIR1, RCIF ; Interrupcion usart?
    call interrupt_usart

    call cargar_contexto
    retfie ; interrupt
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;; CONFIGURACION INICIAL ;;;;;;;;;;;;;;;;;;;;;;;;;;;

configuracion_inicial	
    ; Configuro las entradas de voltaje analogicas (PUERTOA).
    banksel TRISA
    bsf TRISA, 0 ; Seteo RA0 como entrada (perilla analogica)
    bsf TRISA, 1 ; Seteo RA1 como entrada (perilla analógica)
    banksel ANSEL
    bsf ANSEL, 0 ; Seto el puerto RA0 como analogico.
    bsf ANSEL, 1 ; Seto el puerto RA1 como analogico.

    ; Configuracion de la conversión analógica.
    banksel ADCON1
    clrf ADCON1 ; ADFM = Left justified | VCFG1 = Vss | VCFG0 = Vdd	
    ; Configuración del reloj y encendido del conversor analogico.
    banksel ADCON0 
    movlw b'10000001'
    movwf ADCON0 ; ADCS = Fosc/32 (TAD: 1.6(x10^-6)s) | ADON = ADC is enabled.

    ; Configuro las interrupciones.
    bsf INTCON, GIE ; Global interrupt enable bit.
    bsf INTCON, PEIE ; Pheripheral interrupt enable bit.
	
    ; Configuracion puerto serie (EUSART)
    ; Configuracion baudrate
    banksel TXSTA
    bsf TXSTA, BRGH ; BRGH = High Speed
    banksel BAUDCTL
    bcf BAUDCTL, BRG16 ; BRG16 = 8-bit Baud Rate Generator is used.
    banksel SPBRGH
    clrf SPBRGH
    banksel SPBRG
    movlw d'129' 	
    movwf SPBRG ; Baudrate 9600
    ; Configuro la transmision.
    banksel TXSTA
    bsf TXSTA, TXEN  ; Transmit Enable bit = Transmit enabled
    bcf TXSTA, SYNC  ; EUSART mode select bit = Asynchronous mode
    ; Configuro la recepcion.
    banksel RCSTA
    bsf RCSTA, CREN  ; Continuous Recive Enable bit = Enables receiver
    bsf RCSTA, SPEN  ; Serial Port Enable bit = Serial port enabled.
    banksel PIE1 
    bsf PIE1, RCIE ; Configuro que se generen interrupciones con la recepción
	
    return ; configurar_puertos

;;;;;;;;;;;;;;;;;;;;;;;;;;;;; RUTINAS PROGRAMA PRINCIPAL ;;;;;;;;;;;;;;;;;;;;;;

; Lee el contenido del puerto y dervia en un case que indica que letra se
; ingresó.
interrupt_usart
    banksel RCREG
    movf RCREG, w
    call case_letras
    return ; interrupt_usart
	
; Identifica que letra se leyó en el puerto USART.	
case_letras
    xorlw b'01000001' ; 0x41 = 'A' (ASCII)
    btfsc STATUS, Z
    call rutina_letra_A
 
    xorlw b'01100001' ^ b'01000001' ; 0x61 = 'a' (ASCII)
    btfsc STATUS, Z               
    call rutina_letra_a
	
    return ; case_letras

; Rutina de letra A: Obtiene el valor actual de la conversion y la envía por
; el puerto usart.
rutina_letra_A
    call guardar_contexto_case

    banksel VALOR_CONVERSION
    movf VALOR_CONVERSION, w
    call enviar_conversion_usart_hexa

    call cargar_contexto_case
    
    return ; rutina_letra_A
    
; Manda la conversion en formato decimal.
rutina_letra_a
    call guardar_contexto_case
    
    banksel VALOR_CONVERSION
    movf VALOR_CONVERSION, w
    call enviar_conversion_usart_dec
    
     ; Envío grados centrígrados.
    movlw d'167' ; °
    call enviar_w
    movlw d'67' ; C
    call enviar_w    
   
    call cargar_contexto_case
    
    return ; rutina_letra_a
    
; Obtiene el valor de la conversion en w, lo mapea a decimal y lo envía por el
; puerto usart.
enviar_conversion_usart_dec
    banksel VALOR_CONVERSION_TEMP
    movwf VALOR_CONVERSION_TEMP
    
    banksel MULTIPLICANDO_REGLA
    movlw d'100'
    movwf MULTIPLICANDO_REGLA
    
    banksel DIVISOR_REGLA
    movlw d'255'
    movwf DIVISOR_REGLA
 
    banksel VALOR_CONVERSION_TEMP
    movf VALOR_CONVERSION_TEMP, w
    
    call regla_de_tres
    
    banksel REGLAE
    movf REGLAE, w
    call mapear_enviar_dec
    
    return ; enviar_conversion_usart_dec

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
	goto $+6
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
	    movf DIVIDENDO
	    subwf PRODL
	    ; INICIO IF
		btfsc STATUS, C
		; THEN (PRODL >= DIVIDENDO)
		goto restar_dividir
		; ELSE (PRODL < DIVIDENDO)
		movf DIVIDENDO, w
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
		btfss STATUS, C
		; THEN (PRODL >= DIVIDENDO)
		goto $+2
		; ELSE (PRODL < DIVIDENDO)
		decf PRODH, f
	    goto loop_dividir
	
    return ; dividir

; Mapea y envía un valor decimal por el puerto usart.
mapear_enviar_dec
    call convertir_dec_ascii
    
    banksel ASCII1
    movf ASCII1, w
    call enviar_w
    
    banksel ASCII2
    movf ASCII2, w
    call enviar_w
    
    banksel ASCII3
    movf ASCII3, w
    call enviar_w   
    
    return ; mapear_enviar_dec

; Convierte el valor numerico de w en ASCII.
; w = ASCII3 ASCII2 ASCII1
convertir_dec_ascii    
    call convertir_valor_dec
    banksel ASCII_TEMP
    movwf ASCII_TEMP
    movf ASCII_CONVERSION, w
    movwf ASCII3 ; Almaceno el resultado
    
    movf ASCII_TEMP, w
    call convertir_valor_dec
    banksel ASCII_TEMP
    movwf ASCII_TEMP
    movf ASCII_CONVERSION, w
    movwf ASCII2 ; Almaceno el resultado
    
    movf ASCII_TEMP, w
    call convertir_valor_dec
    banksel ASCII_TEMP
    movwf ASCII_TEMP
    movf ASCII_CONVERSION, w
    movwf ASCII1 ; Almaceno el resultado
    
    return ; convertir_dec_ascii
   
; Convierte solo una parte del valor en w.
; ASCII_CONVERSION = w MOD DIVISOR
; w = w/DIVISOR
convertir_valor_dec
    banksel PRODL
    movwf PRODL
    movlw d'10'
    call dividir
    
    banksel RESTO
    movf RESTO, w    
    addlw b'00110000' ; Sumo 30.
    movwf ASCII_CONVERSION ; Almaceno el resultado
    
    banksel COCIENTE
    movf COCIENTE, w
    
    return ; convertir_valor_dec
    
; Obtiene el valor de la conversión en w, lo mapea y lo envía por el puerto
; usart.
enviar_conversion_usart_hexa	
    banksel VALOR_CONVERSION_TEMP
    movwf VALOR_CONVERSION_TEMP

    ; Obtengo los valores High y Low de la conversion.
    andlw d'11110000'
    banksel VALOR_CONVERSIONH
    movwf VALOR_CONVERSIONH
    swapf VALOR_CONVERSIONH, f 	; Hago swamp para cambiar de lugar y 
				; tener todos en los bits menos significativos.
    
    banksel VALOR_CONVERSION_TEMP
    movf VALOR_CONVERSION_TEMP, w
    andlw d'00001111'
    banksel VALOR_CONVERSIONL
    movwf VALOR_CONVERSIONL
    
    ; Mapeo y envío los valores por el puerto usart.
    banksel VALOR_CONVERSIONL
    movf VALOR_CONVERSIONL, w
    call mapear_enviar_hexa
	
    banksel VALOR_CONVERSIONH
    movf VALOR_CONVERSIONH, w
    call mapear_enviar_hexa
    
    return ; enviar_conversion_usart_hexa
	
; Mapea el valor de w a un caracter ASCII y lo envía por el puerto USART.
mapear_enviar_hexa 
    call mapear_hexa    
    call enviar_w
    return ; mapear_enviar_hexa
	
; Envia el valor del registro w por el puerto USART.
enviar_w
    banksel PIR1
    btfss PIR1, TXIF ; Esta vacío el bus de transmisión?
    goto $-1 ; No, vuelvo a chequear hasta que esté libre.
    banksel TXREG
    movwf TXREG 
    return ; enviar_w
	
; Mapea el valor de w a un caracter ASCII y lo guarda en w.
mapear_hexa
    banksel TEMP_W
    movwf TEMP_W
    sublw b'00001001' ; 0x09 -> 9 decimal
    ; INICIO IF
	btfss STATUS, C
	; THEN (w > 9)
	goto sumar_37 ; Es mayor a 9, entonces sumo 0x37 = 0011 0111
	; ELSE (w <= 9)
	goto sumar_30 ; Es menor o igual 9, entonces sumo 0x30 = 0011 0000
    ; FIN IF

; Sumo 30h al valor que tengo en w.
sumar_30
    banksel TEMP_W
    movf TEMP_W, w
    addlw b'00110000' ; 0x30 -> 48 decimal
    return ; mapear_hexa

; Sumo 37h al valor que tengo en w.
sumar_37
    banksel TEMP_W
    movf TEMP_W, w
    addlw b'00110111' ; 0x37 -> 55 decimal
    return ; mapear_hexa
	
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
    movwf W_TEMP  ; Guardo w.
    swapf STATUS, w ; Swap status en w.
    movwf STATUS_TEMP ; Guardo STATUS.
    
    return ; guardar_contexto
	
guardar_contexto_case
    movwf W_TEMP_CASE  ; Guardo w.
    swapf STATUS, w ; Swap status en w.
    movwf STATUS_TEMP_CASE ; Guardo STATUS.

    return ; guardar_contexto_case
    
cargar_contexto
    swapf STATUS_TEMP, w
    movwf STATUS
    swapf W_TEMP, f
    swapf W_TEMP, w
    
    return ; cargar_contexto
	
cargar_contexto_case
    swapf STATUS_TEMP_CASE, w
    movwf STATUS
    swapf W_TEMP_CASE, f
    swapf W_TEMP_CASE, w

    return ; cargar_contexto_case
	
end