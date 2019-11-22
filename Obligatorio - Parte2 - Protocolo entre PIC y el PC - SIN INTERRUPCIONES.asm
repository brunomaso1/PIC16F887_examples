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
    call leer_usart
    goto mainloop
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;; RUTINA DE INTERRUPCION ;;;;;;;;;;;;;;;;;;;;;;;;;;

interrupt
    call guardar_contexto

    ; Identifico la interrupcion.
    banksel PIR1
    btfss PIR1, TMR1IF ; Interrupcion timer1?
    goto $+3
    bcf PIR1, TMR1IF
    call interrupt_tmr1
    
    banksel PIR2
    btfss PIR2, EEIF; Interrupcion escritura?
    goto $+3
    bcf PIR2, EEIF
    call interrupt_eeprom    

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

     ; Chequeo inicial de la memoria EEPROM.
    movlw 0x30
    call leer_memoria
    ; Chequeo que en la dirección 0x30 exista el valor 0x77. Si existe este 
    ; valor significa que la memoria está inicializada, sino hay que
    ; inicializarla.
    sublw 0x77
    ; INICIO IF
	btfsc STATUS, Z
	; THEN (w = 0x77)
	goto $+2
	; ELSE (w <> 0x77)
	call inicializar_eeprom
    ; FIN IF   
    
     ; Configuro el timer1.
    banksel PIE1 ;  Timer1 Overflow Interrupt Enable bit
    bsf PIE1, TMR1IE    
    banksel PIR1
    bcf PIR1, TMR1IF ; Timer1 Overflow Interrupt Flag bit
    banksel T1CON
    bcf T1CON, TMR1CS ; Timer1 Clock Source Select bit = Clock
    ; Configurar preescaler timer1(1:8)
    bsf T1CON, T1CKPS0
    bsf T1CON, T1CKPS1
    bsf T1CON, TMR1ON ; Encender el timer.
    ; Reinicio el contador tmr1.
    call re_iniciar_contador1
    ; Reinicio el timer1.
    call re_iniciar_timer1
	
    return ; configurar_puertos

;;;;;;;;;;;;;;;;;;;;;;;;;;;;; RUTINAS PROGRAMA PRINCIPAL ;;;;;;;;;;;;;;;;;;;;;;

leer_usart
    banksel PIR1
    btfss PIR1, RCIF ; Interrupcion usart?
    goto $+3
    call interrupt_usart ; NO ANDA ESTO, SE HARDCODEA.
    bcf PIR1, RCIF
    
    return ; leer_usart
    
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
 
    xorlw b'01001000' ^ b'01000001' ; 0x48 = 'H' (ASCII)
    btfsc STATUS, Z               
    call rutina_letra_H
	
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
rutina_letra_H
    call guardar_contexto_case
    
    ; Leo el puntero del buffer actual.
    movlw 0x31
    call leer_memoria
    
    ; Guardo el valor del puntero actual.
    banksel PUNTERO_ACTUAL
    movwf PUNTERO_ACTUAL
    
    ; Guardo el valor inicial de ITERADOR.
    banksel ITERADOR
    movwf ITERADOR

    WhileLoopInicio
	; Obtengo el dato que apunta ITERADOR.
	banksel ITERADOR
	movf ITERADOR, w
	banksel EEADR
	movwf EEADR
	call leer_memoria
	
	; Envío el dato (contenido en w) por el puerto usart.
	call enviar_conversion_usart_hexa
	; Envío un salto de linea.
	movlw d'10'
	call enviar_w
	
	; Incremento ITERADOR.
	banksel ITERADOR
	decf ITERADOR, f
	; Chequeo que no me pase el buffer.
	movf ITERADOR, w
	sublw 0x3F
	; INICIO IF
	    btfss STATUS, C	    
	    ; THEN (w > 0x3F)
	    goto $+3
	    ; ELSE (w <= 0x3F)
	    movlw 0x49
	    movwf ITERADOR
	; FIN IF
	
	; Compruebo que no llegue al PUNTERO_ACTUAL (fin del loop)	
	banksel PUNTERO_ACTUAL
	movf PUNTERO_ACTUAL, w
	banksel ITERADOR
	subwf ITERADOR, w
	; INICIO IF
	    btfsc STATUS, Z
	    ; THEN (ITERADOR = PUNTERO_ACTUAL)
	    goto $+2 
	    ; ELSE (ITERADOR <> PUNTERO_ACTUAL)
	    goto WhileLoopInicio
	; FIN IF
    call cargar_contexto_case
    
    return ; rutina_letra_H
	
; Obtiene el valor de la conversión en w, lo mapea y lo envía por el puerto
; usart.
enviar_conversion_usart_hexa	
    banksel VALOR_CONVERSION_TEMP
    movwf VALOR_CONVERSION_TEMP

    ; Obtengo los valores High y Low de la conversion.
    andlw b'11110000'
    banksel VALOR_CONVERSIONH
    movwf VALOR_CONVERSIONH
    swapf VALOR_CONVERSIONH, f 	; Hago swamp para cambiar de lugar y 
				; tener todos en los bits menos significativos.
    
    banksel VALOR_CONVERSION_TEMP
    movf VALOR_CONVERSION_TEMP, w
    andlw b'00001111'
    banksel VALOR_CONVERSIONL
    movwf VALOR_CONVERSIONL
    
    banksel VALOR_CONVERSIONH
    movf VALOR_CONVERSIONH, w
    call mapear_enviar_hexa
    
    ; Mapeo y envío los valores por el puerto usart.
    banksel VALOR_CONVERSIONL
    movf VALOR_CONVERSIONL, w
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
	
; Inicializa la memoria EEPROM.
inicializar_eeprom
    ; Inicializo la flag de memoria inicializada.
    ; Cargo 0x30 (Puntero flag del buffer)
    movlw 0x30
    banksel EEADR
    movwf EEADR
    ; Cargo el dato que indica que está inicializada la memoria.
    movlw 0x77
    banksel EEDAT
    movwf EEDAT
    ; Guardo el valor de w en memoria.
    call guardar_memoria

    ; Inicializo el puntero inicial del donde arranca el buffer.
    ; Cargo 0x31 (SIGUIENTE_PUNTERO)
    movlw 0x31
    banksel EEADR
    movwf EEADR
    ; Cargo el dato que indica que está inicializada la memoria.
    movlw 0x49
    banksel EEDAT
    movwf EEDAT
    ; Guardo el valor de w en memoria.
    call guardar_memoria

    return ; inicializar_eeprom

; Guarda el valor de VALOR_CONVERSION en el buffer circular.
guardar_memoria_VALOR_CONVERSION
    ; Cargo SIGUIENTE_PUNTERO e impacto en memoria.
    call obtener_siguiente_puntero
    ; Cargo el dato de VALOR_CONVERSION en EEDAT.
    banksel VALOR_CONVERSION
    movf VALOR_CONVERSION, w
    banksel EEDAT
    movwf EEDAT
    ; Cargo el puntero de SIGUIENTE_PUNTERO en EEADR.
    banksel SIGUIENTE_PUNTERO
    movf SIGUIENTE_PUNTERO, w
    banksel EEADR
    movwf EEADR
    ; Guardo el valor de w en memoria.
    call guardar_memoria

    return ; guardar_memoria_VALOR_CONVERSION

; Obtiene y guarda el siguiente puntero del buffer en memoria.	
obtener_siguiente_puntero
    ; Cargo 0X31 (Puntero de SIGUIENTE_PUNTERO) en EEADR
    movlw 0x31
    banksel EEADR
    movwf EEADR
    ; Cargo el valor de memoria en w.
    call leer_memoria

    ; Sumo 1 al puntero.
    addlw d'1'
    banksel SIGUIENTE_PUNTERO
    movwf SIGUIENTE_PUNTERO

    ; Chequeo que no me pase del buffer.
    sublw 0x49
    ; INICIO IF
	btfsc STATUS, C
	; THEN (w <= 0x49)
	goto $+3
	; ELSE (w > 0x49)
	movlw 0x40
	movwf SIGUIENTE_PUNTERO
    ; FIN IF

    ; Cargo el dato de SIGUIENTE_PUNTERO en EEDAT.
    movf SIGUIENTE_PUNTERO, w
    banksel EEDAT
    movwf EEDAT
    ; Cargo el puntero de SIGUIENTE_PUNTERO en EEADR.
    movlw 0x31
    banksel EEADR
    movwf EEADR
    ; Guardo el valor de w en memoria.
    call guardar_memoria	

    return ; obtener_siguiente_puntero

; Leo un valor ya seteado en EEADR de memoria en w.
leer_memoria
    banksel EEADR
    movwf EEADR ; Cargo la dirección.

    banksel EECON1
    bcf EECON1, EEPGD ; Apunto a la EEPROM
    bsf EECON1, RD ; Activo la lectura.
    banksel EEDAT
    movf EEDAT, w ; Guardo el valor en w.

    return ; leer_memoria

guardar_memoria
    banksel EECON1
    bcf EECON1, EEPGD ; Apunto a la EEPROM
    bsf EECON1, WREN ; Activo la escritura.

    bcf INTCON, GIE ; Desactivo interrupciones.
    btfsc INTCON, GIE
    goto $-2

    ; SECCION INTOCABLE
    movlw 0x55
    movwf EECON2
    movlw 0xAA
    movwf EECON2
    bsf EECON1, WR ; Se comienza la escritura.
    ; FIN SECCION INTOCABLE

    bsf INTCON, GIE ; Activo las interrupciones.
    btfsc EECON1, WR
    goto $-1
    bcf EECON1, WREN
    return ; guardar_memoria
	
; Configurar CONTADOR_TIMER1
re_iniciar_contador1
    banksel CONTADOR_TIMER1
    movlw d'100'
    movwf CONTADOR_TIMER1

    return ; re_iniciar_contador1

; Rutina de interrupción del tmr1.
interrupt_tmr1
    ; Decremento el contador.
    banksel CONTADOR_TIMER1
    ; INICIO IF
	    decfsz CONTADOR_TIMER1, f
	    ; CONTADOR_TIMER <> 0 THEN
	    goto $+3
	    ; ELSE
	    call guardar_memoria_VALOR_CONVERSION
	    call re_iniciar_contador1
    ; FIN IF
    call re_iniciar_timer1

    return ; interrupt_tmr1

; Interrupcion de escritura de la eepron.
interrupt_eeprom
    banksel PIR2
    bcf PIR2, EEIF ; Limpio la interrupcion de la eeprom

    return ; interrupt_eeprom

; Inicia el timer con el valor precargado, para una interrupción cada 100 ms.
re_iniciar_timer1
;;;;;;;;;;;; Calculo para la cantidad de tiempo ;;;;;;;;;;;;;;;;
    ; ValorTimer = ValorMaximoTimer - ((DelaySolicitado * Fosc) / (Prescalar * 4))
    ; Formula para 100 ms: ValorTimer = 65536 - ((100ms * 20Mhz) / (8 * 4)) = 3036

    ; Cargar 3036 (00001011 11011100)
    banksel PIR1
    
    movlw b'11011100' 
    movwf  TMR1L
    movlw b'00001011' 
    movwf  TMR1H
    
    bcf PIR1, TMR1IF ; Timer1 Overflow Interrupt Flag bit
    return ; re_iniciar_timer1

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
	
guardar_contexto_case
    banksel W_TEMP_CASE
    movwf W_TEMP_CASE  ; Guardo w.
    swapf STATUS, w ; Swap status en w.
    movwf STATUS_TEMP_CASE ; Guardo STATUS.

    return ; guardar_contexto_case
    
cargar_contexto
    banksel STATUS_TEMP
    swapf STATUS_TEMP, w
    movwf STATUS
    swapf W_TEMP, f
    swapf W_TEMP, w
    return ; cargar_contexto
	
cargar_contexto_case
    banksel STATUS_TEMP_CASE
    swapf STATUS_TEMP_CASE, w
    movwf STATUS
    swapf W_TEMP_CASE, f
    swapf W_TEMP_CASE, w

    return ; cargar_contexto_case

end