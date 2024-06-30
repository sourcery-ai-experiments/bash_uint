#!/usr/bin/env bash

shopt -s extglob
shopt -s patsub_replacement

dec2uint () (
    ## convert (compress) ascii text integers into uint representation integers
    # values may be passed via the cmdline or via stdin
    # immediately before each value printed as a uint, there will be a 1 byte hexadecimal pair:
    #    1st hex (first 4 bits): tells how many (0-15/f) NULL-delimited reads are needed to read the [start of] the following number
    #    2nd hex (last 4 bits):  tells how many (0-15/f) additional bytes must be read (after the last NULL-delimited read) to read the [end of] the following number
    # after the last value a NULL we be printed (unless -n flag is set)
    # flags: if the 1st command-line input is '-n' then the final trailing NULL will be omitted
    
    local -a A;
    local a a0 a1 a2 b nn noTrailingNullFlag;    

    if [[ "${1}" == '-n' ]] ; then
        noTrailingNullFlag=true;
        shift 1;
    else
        noTrailingNullFlag=false;
    fi
    
    for nn in "${@}"; do
        printf -v a '%x' "$nn";
        (( ( ${#a} & 1 ) == 0 )) || a="0${a}";
        a="${a//@([0-9a-f])@([0-9a-f])/& }";
        a1="${a//@([1-9a-f][0-9a-f]||[0-9a-f][1-9a-f]|| )/}";
        a2="${a//@(*00|| )/}";
        printf -v a0 '%x' "$(( ${#a1} >> 1 ))" "$(( ${#a2} >> 1 ))";
        printf -v b '\\x%s' "${a0}" ${a};
        printf "$b";
    done
    
    ${noTrailingNullFlag} || [[ "${FUNCNAME[0]}" == "${FUNCNAME[1]}" ]] ||  {
        [ -t 0 ] || {
            mapfile -t A <(cat <&${fd0});
            dec2uint -n "${A[@]}";
        } {fd0}<&0    
    
        printf '\0';
    }

)

uint2dec() (
    ## convert (expand) uint representation integers into ascii text integers
    # values may be passed via stdin only (passing on cmdline would drop NULL bytes)
    # NOTE: uint2dec expects each value to have a 1-byte hexidecimal pair (as described in dec2uint) immediately before each number:
    #    1st hex (first 4 bits): tells how many (0-15/f) NULL-delimited reads are needed to read the [start of] the following number
    #    2nd hex (last 4 bits):  tells how many (0-15/f) additional bytes must be read (after the last NULL-delimited read) to read the [end of] the following number
    
    (
        IFS=
        
        local -a A;
        local a b c n n0 n1 REPLY;
    
        while true; do
            read -r -N 1 -u ${fd0};
            
            [[ $REPLY ]] || break;
            
            printf -v n '%d' "'"${REPLY};
            n0=$(( ( $n & 240 ) >> 4 ));
            n1=$(( $n & 15 ));
            printf 'n=%s    n0=%s   n1=%s \n' $n $n0 $n1 >&2;
            
            if [[ "$n0" == 0 ]]; then
                A=();
            else
                mapfile -t -n ${n0} -d '' -u ${fd0} A;
                A=("${A[@]/%/' 0 '}");
                A=("${A[@]@Q}");
            fi

            if [[ "$n1" == 0 ]]; then
                a=''
            else
                read -r -N 1 -u ${fd0} a;
                a="${a@Q}"
            fi

            b="${A[*]//@(\$||\'|| ||$'\t'||$'\n'||$'\v')/}${a//@(\$||\'|| ||$'\t'||$'\n'||$'\v')/}";

            printf -v c '%02x' ${b//\\/ 0};
            printf '%i ' $(( 16#"${c}" ));
            
        done
    ) {fd0}<&0
)
