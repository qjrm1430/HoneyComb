[ORG 0x00] ; 코드의 시작 어드레스를 0x00으로 설정
[BITS 16] ; 이하의 코드는 16비트 코드로 설정

SECTION .text ; text 섹션(세그먼트)을 정의


jmp 0x07C0:START ; CS세그먼트 레지스터에 0x07C0을 복사하면서 START 레이블로 이동

START:
	mov ax, 0x07C0 	; 부트로더의 시작 어드레스(0x7C00)를 세그먼트 레지스터 값으로 변환
	mov ds, ax 		; DS 세그먼트 레지스터에 설정
	mov ax, 0xB800 	; 비디오메모리의 시작어드레스(0xB800)를 세그먼트 레지스터 값으로 변환
	mov es, ax 		; ES 세그먼트 레지스터에 설정

	mov si, 0 		; Initialize si register

.SCREENCLEARLOOP:
	mov byte [ es: si ], 0 ; delete character at si index
	mov byte [ es: si + 1], 0x0A ; copy 0x)A(black / gree)
	add si, 2 ; go to next location
	cmp si, 80 * 25 *2 ; compare si and screen size

	jl .SCREENCLEARLOOP ; end loop if si == screen size

	mov si, 0 ; initialize si register
	mov di, 0 ; initialize di register

.MESSAGELOOP:
	mov cl, byte [ si + MESSAGE1 ] ; copy charactor which is on the address MESSAGE1's addr + SI register's value

	cmp cl, 0 ; compare the charactor and 0
	je .MESSAGEEND ; if value is 0 -> string index is out of bound -> finish the routine
	mov byte [ es : di], cl ; if value is not 0 -> print the charactor on 0xB800 + di

	add si, 1 ; go to next index
	add di, 2 ; go to next video address

	jmp .MESSAGELOOP ; loop code

.MESSAGEEND:
	jmp $ ; infinite loop

MESSAGE1: db 'OS Boot Loader Start!!', 0 ; define the string tha I want to print

times 510 - ($ - $$) db 0x00 	; $: 현재 라인의 어드레스
								; $$: 현재 섹션(.text)의 시작 어드레스
								; $ -$$: 현재 섹션을 기준으로 하는 오프셋
								; 510 - ($ - $$): 현재부터 어드레스 510까지
								; db 0x00: 1바이트를 선언하고 값은 0x00
								; time: 반복수행
								; 현재 위치에서 어드레스 510까지 0x00으로 채움
db 0x55 ; 1바이트를 선언하고 값은 0x55
db 0xAA ; 1바이트를 선언하고 값은 0xAA
		; 어드레스 511, 512에 0x55, 0xAA를 써서 부트 섹터로 표기함
