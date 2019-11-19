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
    CONTADOR_TIMER1 ; 0x30
    SIGUIENTE_PUNTERO ; 0X31
    PUNTERO_ACTUAL ; 0x32
    TEMP_W ; 0x33
    STATUS_TEMP_CASE ; 0x34
    W_TEMP_CASE ; 0x35
    ITERADOR ; 0x36

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
    
; Rutina de letra H: Obtiene los valores de memoria del buffer circular y los
; envía por el puerto usart.
rutina_letra_a
    call guardar_contexto_case
    
    banksel VALOR_CONVERSION
    movf VALOR_CONVERSION, w
    call enviar_conversion_usart_dec
    
     ; Envío grados centrígrados.
    movlw d'167'
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
    
    
    
    return ; enviar_conversion_usart_dec

	
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
    btfsc STATUS, Z
    goto sumar_30 ; Es 9, entonces sumo 0x30 = 0011 0000
    btfsc STATUS, C
    goto sumar_37 ; Es mayor a 9, entonces sumo 0x37 = 0011 0111
    goto sumar_30 ; Es menor 9, entonces sumo 0x30 = 0011 0000

; Sumo 30h al valor que tengo en w.
sumar_30
    banksel TEMP_W
    movf TEMP_W, w
    addlw b'00110000' ; 0x30 -> 48 decimal
    return ; sumar_30

; Sumo 37h al valor que tengo en w.
sumar_37
    banksel TEMP_W
    movf TEMP_W, w
    addlw b'00110111' ; 0x37 -> 55 decimal
    return ; sumar_37
	
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