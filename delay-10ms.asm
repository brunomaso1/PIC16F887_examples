    global delay_10ms_w
    global delay_10ms
    
delay_10ms_vars udata
d1 res 1
d2 res 1
r1 res 1

    code
; one single 10ms delay    
delay_10ms
        banksel d1
	movlw 0x0E
	movwf d1
	movlw 0x28
	movwf d2
delay_10ms_0
	decfsz d1, f
	goto $+2
	decfsz d2, f
	goto delay_10ms_0
	nop
	return
	
; calls delay_10ms w times
delay_10ms_w
	banksel r1
	movwf r1
	call delay_10ms
	decfsz r1
	goto $-2
	return	
    end
