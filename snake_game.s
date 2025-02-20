extern _tcsetattr   ; Modifier les attributs du terminal (configurer le mode d'affichage)
extern _tcgetattr   ; Obtenir les attributs actuels du terminal
extern _printf      ; Afficher du texte (fonction printf de la bibliothèque C)
extern _fflush      ; Vider le buffer de sortie (pour l'affichage immédiat)
extern _getchar     ; Lire un caractère depuis l'entrée standard
extern _usleep      ; Pause d'exécution (dormir un certain temps)
extern _select      ; Vérifier l'état des entrées (utile pour la détection de touches)
extern _rand        ; Générer un nombre aléatoire


default rel
global _main

%define COLS 60 ;(colonnes) → 60 caractères de large
%define ROWS 30 ;(lignes) → 30 caractères de haut

section .data
hidecursor: db 27, '[?25l', 0 ;Code pour cacher le curseur (ANSI escape sequence)
showcursor: db 27, '[?25h', 0 ;Code pour réafficher le curseur
cursortotop: db 27, '[%iA', 0 ;Code pour déplacer le curseur vers le haut
cursortotop2: db 27, '[%iF', 0
gameoverstr:  db 27, '[%iB', 27, '[%iC Game Over! ', 0 ;Chaîne pour afficher "Game Over" en fin de partie
tailstr:      db 27, '[%iB', 27, '[%iC·', 0 ;Caractère utilisé pour dessiner le corps du serpent
headstr:      db 27, '[%iB', 27, '[%iC▓', 0 ;Caractère utilisé pour dessiner la tête du serpent
applestr:     db 27, '[%iB', 27, '[%iC❤', 0 ;Symbole utilisé pour représenter la pomme



section .bss
data: resb 1
oldt: resb 64
newt: resb 64
buf: resq COLS * ROWS +1 ;Buffer qui contient la grille du jeu
x:      resq 1024 ;Coordonnées des abscisses du serpent
y:      resq 1024 ;Coordonnées des ordonnées du serpent
xdir:   resq 1 ;Direction du déplacement
ydir:   resq 1
head:   resq 1 ;Indices de la tête et de la queue du serpent.
tail:   resq 1
applex: resq 1 ;Position de la pomme sur la grille.
appley: resq 1
tv:     resq 2
fds:    resq 16

section .text
init:
    push rbp
    mov rdi, hidecursor
    call _printf
    xor rdi, rdi
    call _fflush

    ;switch to console mode, disable echo
    mov rdi, 0
    mov rsi, oldt
    call _tcgetattr

    mov rdi, newt
    mov rsi, oldt
    mov rcx, 64
    rep movsb

    and word [newt + 3 *8], ~(0x0100 | 0x0008);
    mov rdi, 0
    mov rsi, 0
    mov rdx, newt
    call _tcsetattr
    pop rbp
    ret

exit:
    mov rdi , showcursor
    call _printf
    xor rdi, rdi
    call _fflush


    ;restore terminal mode
    mov rdi, 0
    mov rsi, 0
    mov rdx, oldt
    call _tcsetattr

    mov rax, 60
    xor rdi, rdi
    syscall

    ;jmp exit


render_table:
    push rbp
    mov rdi, buf
    mov   rax, '┌'
    stosd
    dec rdi
    mov rcx, COLS
    mov   rax, '─'

_r0:
    stosd
    dec rdi
    dec rcx
    jnz _r0
    mov   rax, '┐'
    stosd
    mov byte [ rdi - 1], 10 ;new line

    ;mid line
    mov rdi, ROWS
_r1:
    mov   rax, '│'
    stosd
    dec rdi
    mov rcx, COLS
    mov ax, ''
    rep stosw
    mov   eax, '│'
    stosd
    mov byte [rdi - 1], 10
    dec rsi
    jnz _r1

    ;bottom line
    mov   rax, '└'
    stosd
    dec   rdi
    mov   rcx, COLS
    mov   rax, '─'

_r2:
    stosd
    dec rdi
    dec rcx
    jnz _r2
    mov rax, '┘'
    mov   byte [rdi - 1], 10 ; new line


    mov rdi, buf
    call _printf

    mov rdi, cursortotop
    mov rsi, ROWS + 2
    call _printf


    pop rbp
    ret

_main:
    push rbp
    call init

main_loop:
    call render_table
    mov   qword [tail], 0
    mov   qword [head], 0
    mov   qword [x], COLS / 2
    mov   qword [y], ROWS / 2
    mov   qword [xdir], 1
    mov   qword [ydir], 0
    mov   qword [applex], -1

loop:
    lea   rbp, [data]
    cmp   qword [applex], 0
    jge   apple_exists

    ; Create new apple
    call  _rand
    xor   rdx, rdx
    mov   rbx, COLS
    div   rbx
    mov   [applex], rdx
    call  _rand
    xor   rdx, rdx
    mov   rbx, ROWS
    div   rbx
    mov   [appley], rdx

    ; New apple on the snake?
    mov   rdi, [head]
    mov   rax, [applex]
    mov   rbx, [appley]
    mov   rsi, [tail]
q3:
    cmp   rsi, [head]
    jz    q5
    cmp   [rbp + (x - data) + rsi * 8], rax
    jnz   q4
    cmp   [rbp + (y - data) + rsi * 8], rbx
    jnz   q4
    mov   qword [applex], -1
q4:
    inc   rsi
    and   rsi, 1023
    jmp   q3
q5:

    ; Draw apple
    cmp   qword [applex], 0
    jl    apple_exists
    mov   rdi, applestr
    mov   rsi, [appley]
    mov   rdx, [applex]
    inc   rsi
    inc   rdx
    call  _printf
    mov   rdi, cursortotop2
    mov   rsi, [appley]
    inc   rsi
    call  _printf

apple_exists:

    ; Clear snake tail
    mov   rbx, [tail]
    mov   rdi, tailstr
    mov   rsi, [rbp + (y - data) + rbx * 8]
    mov   rdx, [rbp + (x - data) + rbx * 8]
    inc   rsi
    inc   rdx
    call  _printf

    mov   rbx, [tail]
    mov   rdi, cursortotop2
    mov   rsi, [rbp + (y - data) + rbx * 8]
    inc   rsi
    call  _printf

    ; Eat apple?
    mov   rbx, [head]
    mov   rax, [rbp + (x - data) + rbx * 8]
    cmp   eax, [applex]
    jnz   not_on_apple
    mov   rax, [rbp + (y - data) + rbx * 8]
    cmp   eax, [appley]
    jnz   not_on_apple

    mov   qword [applex], -1
    jmp   apple_is_eaten

not_on_apple:
    ; Move tail
    mov   rbx, [tail]
    inc   rbx
    and   rbx, 1023
    mov   [tail], rbx
apple_is_eaten:

    ; Move head
    mov   rbx, [head]
    mov   rax, rbx
    inc   rbx
    and   rbx, 1023

    mov   rcx, [rbp + (x - data) + rax * 8]
    add   rcx, [xdir]
    cmp   rcx, COLS
    jb    ok0
    jge   o1
    add   rcx, COLS
    jmp   ok0
o1:
    sub   rcx, COLS
ok0:
    mov   [rbp + (x - data) + rbx * 8], rcx

    mov   rdx, [rbp + (y - data) + rax * 8]
    add   rdx, [ydir]
    cmp   rdx, ROWS
    jb    ok2
    jge   o2
    add   rdx, ROWS
    jmp   ok2
o2:
    sub   rdx, ROWS
ok2:
    mov   [rbp + (y - data) + rbx * 8], rdx
    mov   [head], rbx

    ; Check gameover
    mov   rdi, [head]
    mov   rax, [rbp + (x - data) + rdi * 8]
    mov   rbx, [rbp + (y - data) + rdi * 8]
    mov   rsi, [tail]
r3:
    cmp   rsi, [head]
    jz    r5
    cmp   [rbp + (x - data) + rsi * 8], rax
    jnz   r4
    cmp   [rbp + (y - data) + rsi * 8], rbx
    jz    gameover
r4:
    inc   rsi
    and   rsi, 1023
    jmp   r3
r5:

    ; Draw head
    mov   rbx, [head]
    mov   rdi, headstr
    mov   rsi, [rbp + (y - data) + rbx * 8]
    mov   rdx, [rbp + (x - data) + rbx * 8]
    inc   rsi
    inc   rdx
    call  _printf
    mov   rdi, cursortotop2
    mov   rbx, [head]
    mov   rsi, [rbp + (y - data) + rbx * 8]
    inc   rsi
    call  _printf
    xor   rdi, rdi
    call  _fflush

    ; Delay
    mov   rdi, 5 * 1000000 / 60
    call  _usleep

    ; read keyboard
    mov   qword [fds], 1
    mov   rdi, 1
    mov   rsi, fds
    mov   rdx, 0
    mov   rcx, 0
    mov   qword [tv], 0
    mov   qword [tv + 8], 0
    mov   r8, tv
    call  _select
    test  rax, 1
    jz    nokey

    call  _getchar
    cmp   al, 27
    jz    exit
    cmp   al, 'q'
    jz    exit

    cmp   al, 'h'
    jnz   noth
    cmp   qword [xdir], 1
    jz    noth
    mov   qword [xdir], -1
    mov   qword [ydir], 0
noth:
    cmp   al, 'l'
    jnz   notl
    cmp   qword [xdir], -1
    jz    notl
    mov   qword [xdir], 1
    mov   qword [ydir], 0
notl:
    cmp   al, 'j'
    jnz   notj
    cmp   qword [ydir], -1
    jz    notj
    mov   qword [xdir], 0
    mov   qword [ydir], 1
notj:
    cmp   al, 'k'
    jnz   notk
    cmp   qword [ydir], 1
    jz    notk
    mov   qword [xdir], 0
    mov   qword [ydir], -1
notk:

nokey:
    jmp   loop

gameover:
    ; Show gameover
    mov   rdi, gameoverstr
    mov   rsi, ROWS / 2
    mov   rdx, COLS / 2 - 5
    call  _printf
    mov   rdi, cursortotop2
    mov   rsi, ROWS / 2
    call  _printf

    call  _getchar
    jmp main_loop