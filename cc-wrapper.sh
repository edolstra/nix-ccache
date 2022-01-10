#! @shell@
set -eu

if [[ ! -v NIX_REMOTE ]]; then
    echo "$0: warning: recursive Nix is disabled" >&2
    exec @next@/bin/@program@ "$@"
fi

isCompilation=
cppFlags=()
compileFlags=()
sources=()
dest=

args=("$@")

for ((n = 0; n < $#; n++)); do
    arg="${args[$n]}"

    if [[ $arg = -c ]]; then
        isCompilation=1
    elif [[ $arg = -o ]]; then
        : $((n++))
        dest="${args[$n]}"
    elif [[ $arg = --param ]]; then
        : $((n++))
        cppFlags+=("$arg" "${args[$n]}")
        compileFlags+=("$arg" "${args[$n]}")
    elif [[ $arg = -idirafter || $arg = -I || $arg = -isystem || $arg = -include || $arg = -MF ]]; then
        : $((n++))
        cppFlags+=("$arg" "${args[$n]}")
    elif [[ $arg =~ ^-D.* || $arg =~ ^-I.* ]]; then
        cppFlags+=("$arg")
    elif [[ ! $arg =~ ^- ]]; then
        sources+=("$arg")
    elif [[ $arg =~ ^-frandom-seed= ]]; then
        : # ignore
    else
        cppFlags+=("$arg")
        compileFlags+=("$arg")
    fi
done

if [[ ! $isCompilation || ${#sources[*]} != 1 || ${sources[0]} =~ conftest ]]; then
    #echo "SKIP: ${sources[@]}" >&2
    exec @next@/bin/@program@ "$@"
fi

source="${sources[0]}"

if [[ -z $dest ]]; then
    dest="$(basename "$source" .c).o" # FIXME
fi

if [[ $source =~ \.c$ ]]; then
    ext=i
else
    ext=ii
fi

# set random-seed to a constant value
destEscaped=$(echo "$dest" | tr ' ' _)
cppFlags+=("-frandom-seed=$destEscaped")

#echo "NIX-CCACHE: $@" >&2

#echo "preprocessing to $dest.$ext..." >&2

@next@/bin/@program@ -o "$dest.$ext" -E "$source" "${cppFlags[@]}"

#echo "compiling to $dest..."

escapedArgs='"-o" "${placeholder "out"}" "-c" '$(readlink -f "$dest.$ext")' '

for arg in "${compileFlags[@]}"; do
    escapedArgs+='"'
    escapedArgs+="$arg" # FIXME: escape
    escapedArgs+='" '
done

#echo "FINAL: @next@/bin/@program@ $escapedArgs"

# FIXME: add any store paths mentioned in the arguments (e.g. -B
# flags) to the input closure, or filter them?

@nix@/bin/nix-build --quiet -o "$dest.link" -E '(
  derivation {
    name = "cc";
    system = "@system@";
    builder = builtins.storePath "@next@/bin/@program@";
    extra = builtins.storePath "@binutils@";
    args = [ '"$escapedArgs"' "-B@libexec@/" "-B@binutils@/bin" ];
  }
)' > /dev/null

cp "$dest.link" "$dest"

rm -f "$dest.$ext" "$dest.link"

exit 0
