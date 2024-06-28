#!/usr/bin/env bash

shopt -s extglob
shopt -s patsub_replacement

dec2uint () (
    ## convert (compress) ascii text integers into uint representation integers
    # values may be passed via the cmdline or via stdin
    # immediately before each value printed as a uint, there will be a 1 byte hexadecimal pair:
    #   1st hex: tells how many (0-15) NULL-delimited reads are needed to read the [start of] the following number
    #   2nd hex: tells how many (0-15) additional bytes must be read (after the last NULL-delimited read) to read the [end of] the following number
    
    local -a A;
    local a a0 a1 a2 b nn;    
    
    for nn in "${@}"; do
        printf -v a '%x' "$nn";
        (( ( ${#a} & 1 ) == 0 )) || a="0${a}";
        a="${a//@([0-9a-f])@([0-9a-f])/& }"
        a1=${a//@(@([1-9a-f])@([0-9a-f])||@([0-9a-f])@([1-9a-f])||@( ))/}
        a2=${a##*00}
        a2=${a2// /}
        printf -v a0 '%x' $(( ${#a1} / 2 )) $(( ${#a2} / 2 ))
        printf -v b '\\x%s' "${a0}" ${a//@([0-9a-f])@([0-9a-f])/& };
        printf "$b";
    done
    
    [[ "${FUNCNAME[0]}" == "${FUNCNAME[1]}" ]] ||  {
        [ -t 0 ] || {
            mapfile -t -u ${fd0} A;
            dec2uint "${A[@]}"
        } {fd0}<&0    
    
        printf '\0'
    }

)

uint2dec() (
    ## convert (expand) uint representation integers into ascii text integers
    # values may be passed via stdin only (passing on cmdline would drop NULL bytes)
    # NOTE: expects each value to have a 1-byte hexidecimal pair (described in dec2uint) immediately before each number 
    
    local -a A
    local a b n n0 n1;
    {
        while true; do
            read -r -N 1 -u ${fd0}
            
            [[ $REPLY ]] || break
            
            printf -v n '%d' \'"${REPLY}"
            
            n0=$(( ( $n & 240 ) >> 4 ))
            n1=$(( $n & 15 ))
            
            if [[ "$n0" == 0 ]]; then
                A=()
            else
                mapfile -t -n ${n0} -d '' -u ${fd0} A
                A=("${A[@]//?/\'& }");
                A=(${A[@]/%/' 0x00 '})
            fi
            
            if [[ "$n1" == 0 ]]; then
                a=''
            else
                read -r -N ${n1} -u ${fd0} a
                A+=(${a//?/\'& });
            fi        
        
            printf -v b '%02x' "${A[@]}";
            printf '%i ' $(( 16#"${b}" ));
            
        done
    } {fd0}<&0
)
