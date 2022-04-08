[ORG 0x00] ; 코드의 시작 어드레스를 0x00으로 설정
[BITS 16] ; 이하 코드는 16비트 코드로 설정
SECTION .text ; text 섹션(세그먼트)을 정의

;;;;;;;;;;;
; 코드 영역 ;
;;;;;;;;;;;
START:
    mov ax, 0x1000  ; 보호모드 엔트리 포인트의 시작 어드레스(0x10000)를
                    ; 세그먼트 레지스터 값으로 변환

    mov ds, ax      ; ds에 설정
    mov es, ax      ; es에 설정

    cli ; 인터럽트 발생 못하게
    lgdt [ GDTR ] ; gdtr 자료구조를 프로세서에 설정하여 gdt 테이블을 로드

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; 보호 모드로 진입                                ;
    ; Disable Pagin, Disable Cache, Internal FPU, ;
    ; Disable Align Check, Enable ProtectedMode   ;
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    mov eax, 0x4000003B ; PG=0, NW=0, AM=0, WP=0, NE=1, ET=1, TS=1, EM=0, MP=1, PE=1
    mov cr0, eax ; cr0에 위에서 저장한 플래그를 설정하여 보호모드로 전환
    ; 커널 코드 세그먼트를 0x00을 기준으로 하는 것으로 교체하고 EIP의 값을 0x00을 기준으로 재설정
    ; cs 세그먼트 셀렉터 : EIP
    jmp dword 0x08: ( PROTECTEDMODE - $$ + 0X10000 )
;;;;;;;;;;;;;;;
; 보호모드로 진입 ;
;;;;;;;;;;;;;;;
[BITS 32] ; 이하 코드는 32비트 코드로 설정
PROTECTEDMODE:
    mov ax, 0x10 ; 보호모드 커널용 데이터 세그먼트 디스크립터를 ax에 저장
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    ; 스택을 0x00000000 ~ 0x0000FFFF영역에 64kb크기로 생성
    mov ss, ax
    mov esp, 0xFFFE ; esp addr = 0xfffe
    mov ebp, 0xFFFE ; ebp addr = 0xfffe

    ; 화면에 보호모드로 전환되었다는 메시지를 찍는다.
    push ( SWITCHSUCCESSMESSAGE - $$ + 0X10000 ) ; 출력할 메시지의 어드레스를 스택에 삽입
    push 2 ; 화면 y 좌표(2)를 스택에 삽입
    push 0 ; 화면 x 좌표(0)를 스택에 삽입
    call PRINTMESSAGE ; PRINTMESSAGE 함수 호출
    add esp, 12 ; 삽입한 파라미터 제거

    jmp $ ; 현재 위치에서 무한루프 수행

;;;;;;;;;;;;;;;
; 함수 코드 영역 ;
;;;;;;;;;;;;;;;
; 메시지를 출력하는 함수
; 스택에 x좌표, y좌표, 문자열
PRINTMESSAGE:
    push ebp ; bp를 스택에 삽입
    mov ebp, esp ; bp에 sp 저장
    ; 함수에서 임시로 사용하는 레지스터들로 함수의 마지막 부분에서 스택에 삽입된 값을 꺼내 원래 값으로 복원
    push esi
    push edi
    push eax
    push ecx
    push edx

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; x,y의 좌표로 비디오 메모리의 어드레스를 계산함 ;
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; y 좌표를 이용해서 먼저 라인 어드레스를 구함
    mov eax, dword [ ebp +12 ]  ; 파라미터 2(화면 좌표 y)를 eax에 설정
    mov esi, 160                ; 한라인의 바이트 수(2*80컬럼)를 esi에 설정
    mul esi                     ; eax와 esi를 곱하여 화면 y addr 계산
    mov edi, eax                ; 계산된 화면 y addr를 edi에 설정

    ; x좌표를 이용해서 2를 곱한 후 최종 addr구함
    mov eax, dword [ ebp +8 ]   ; 파라미터 1(화면 좌표 x)를 eax에 설정
    mov esi, 2                  ; 한 문자를 나타내는 바이트 수(2)를 esi에 설정
    mul esi                     ; eax와 esi를 곱하여 화면 x addr를 계산
    add edi, eax                ; 화면 y addr와 계산된 x addr를 더해서 실제 비디오 메모리 어드레스를 계산

    ; 출력할 문자열의 어드레스
    mov esi, dword [ ebp + 16 ] ; 파라미터 3(출력할 문자열의 어드레스)

.MESSAGELOOP: ; 메세지를 출력하는 루프
    mov cl, byte [ esi ]    ; esi가 가리키는 문자열 위치에서 한문자를 cl에 복사
                            ; cl은 ecx의 하위 1바이트를 의미
                            ; 문자열은 1바이트면 충분하므로 ecx의 하위 1바이트만 사용

    cmp cl, 0 ; 복사된 문자와 0을 비교
    je .MESSAGEEND  ; 복사된 문자의 값이 0이면 문자열이 종료되었음을 의미하므로
                    ; .MESSAGEEND로 이동하여 문자 출력 종료

    mov byte [ edi +0xB8000 ], cl ; 0이 아니라면 비디오 메모리 addr ; 0xB8000 + edi에 문자를 출력

    add esi, 1  ; 다음 문자열로 이동
    add edi, 2  ; 비디오 메모리의 다음 문자 위치로 이동
                ; 비디오 메모리는 (문자, 속성) 형식이므로 문자만 출력하려면 2를 더해야 함

    jmp .MESSAGELOOP ; 메시지 출력 루프로 이동하여 다음 문자를 출력

.MESSAGEEND: ; 함수 사용이 끝나면 스택 복원
    pop edx
    pop ecx
    pop eax
    pop edi
    pop esi
    pop ebp ; bp 복원
    ret

;;;;;;;;;;;;
; 데이터 영역 ;
;;;;;;;;;;;;

; 아래의 데이터들을 8바이트에 맞춰 정렬하기 위해 추가
align 8, db 0 ; GDTR의 끝을 8byte로 정렬하기 위해 추가
dw 0x0000 ; GDTR 자료구조 정의
GDTR:
    dw GDTEND - GDT - 1 ; 아래에 위치하는 gdt테이블의 전체 크기
    dd ( GDT - $$ + 0x10000 ) ; 아래에 위치하는 gdt테이블의 시작 주소

;GDT 테이블 정의
GDT:
    ; null디스크립터, 반드시 0으로 초기화해야 함
    NULLDescriptor:
        dw 0x0000
        dw 0x0000
        db 0x00
        db 0x00
        db 0x00
        db 0x00

    ; 보호 모드 커널용 코드 세그먼트 디스크립터
    CODEDESCRIPTOR:
        dw 0xFFFF ; Limit [15:0]
        dw 0x0000 ; Base [15:0]
        db 0x00 ; Base [23:16]
        db 0x9A ; P=1, DPL=0, code segment, Execute/Read
        db 0xCF ; G=1, D=1, L=0, Limit[19:16]
        db 0x00 ; Base [31:24]

    ; 보호모드 커널용 데이터 세그먼트 디스크립터
    DATADESCRIPTOR:
        dw 0xFFFF ; limit [15:0]
        dw 0x0000 ; base [15:0]
        db 0x00 ; base [23:16]
        db 0x92 ; P=1, DPL=0, data segment, read/write
        db 0xCF ; G=1, D=1, L=0, limit[19:16]
        db 0x00 ; base [31:24]
GDTEND: ; GTD 테이블 종료

; 보호모드로 전환되었다는 메시지
SWITCHSUCCESSMESSAGE: db 'Switch To Protected Mode Success!', 0
times 512 - ( $ - $$ ) db 0x00 ; 512바이트를 맞추기 위해 남은 부분을 0으로 채움
