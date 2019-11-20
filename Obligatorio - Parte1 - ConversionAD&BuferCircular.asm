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
; 0x30 -> Flag que indica si está usado el buffer o no.
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
    VALOR_CONVERSION  ; 0x25
    CONTADOR_TIMER1 ; 0x26
    SIGUIENTE_PUNTERO ; 0X27

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

    ; Identifico la interrupcion.
    banksel PIR1
    btfsc PIR1, TMR1IF ; Interrupcion timer1?
    call interrupt_tmr1

    banksel PIR2
    btfsc PIR2, EEIF; Interrupcion escritura?
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
    banksel ADCON1
    clrf ADCON1 ; ADFM = Left justified | VCFG1 = Vss | VCFG0 = Vdd	
    ; Configuración del reloj y encendido del conversor analogico.
    banksel ADCON0 
    movlw b'10000001'
    movwf ADCON0 ; ADCS = Fosc/32 (TAD: 1.6(x10^-6)s) | ADON = ADC is enabled.

    ; Configuro las interrupciones.
    bsf INTCON, GIE ; Global interrupt enable bit.
    bsf INTCON, PEIE ; Pheripheral interrupt enable bit.
	
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
    bcf T1CON, TMR1ON ; Encender el timer.
    ; Reinicio el contador tmr1.
    call re_iniciar_contador1
    ; Reinicio el timer1.
    call re_iniciar_timer1
	
    return ; configurar_puertos

;;;;;;;;;;;;;;;;;;;;;;;;;;;;; RUTINAS PROGRAMA PRINCIPAL ;;;;;;;;;;;;;;;;;;;;;;

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
    movlw 0x40
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
	; ELSE (w > 0x59)
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
    return ; guardar_memoria
	
; Configurar CONTADOR_TIMER1
re_iniciar_contador1
    banksel CONTADOR_TIMER1
    movlw d'10'
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
    movf ADRESH, W
    banksel VALOR_CONVERSION
    movwf VALOR_CONVERSION
    
    return ; realizar_conversion

; Rutinas de contexto.
guardar_contexto
    movwf W_TEMP  ; Guardo w.
    swapf STATUS, w ; Swap status en w.
    movwf STATUS_TEMP ; Guardo STATUS.
    return ; guardar_contexto
	
cargar_contexto
    swapf STATUS_TEMP, w
    movwf STATUS
    swapf W_TEMP, f
    swapf W_TEMP, w
    return ; cargar_contexto
	
end