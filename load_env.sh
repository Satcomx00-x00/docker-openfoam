#!/bin/sh
# Run from OPENFOAM top-level directory only
cd "${0%/*}" || exit
wmake -check-dir "$WM_PROJECT_DIR" 2>/dev/null || {
    echo "Error (${0##*/}) : not located in \$WM_PROJECT_DIR"
    echo "    Check your OpenFOAM environment and installation"
    exit 1
}
if [ -f "$WM_PROJECT_DIR"/wmake/scripts/AllwmakeParseArguments ]
then  . "$WM_PROJECT_DIR"/wmake/scripts/AllwmakeParseArguments || \
    echo "Argument parse error"
else
    echo "Error (${0##*/}) : WM_PROJECT_DIR appears to be incorrect"
    echo "    Check your OpenFOAM environment and installation"
    exit 1
fi

#------------------------------------------------------------------------------
# Preamble. Report tools or at least the mpirun location
if [ -f "$WM_PROJECT_DIR"/wmake/scripts/list_tools ]
then sh "$WM_PROJECT_DIR"/wmake/scripts/list_tools || true
else
    echo "mpirun=$(command -v mpirun || true)"
fi
echo
# Report compiler information. First non-blank line from --version output
compiler="$(wmake -show-path-cxx 2>/dev/null || true)"
if [ -x "$compiler" ]
then
    echo "compiler=$compiler"
    "$compiler" --version 2>/dev/null | sed -e '/^$/d;q'
else
    echo "compiler=unknown"
fi

echo
echo ========================================
date "+%Y-%m-%d %H:%M:%S %z" 2>/dev/null || echo "date is unknown"
echo "Starting compile ${WM_PROJECT_DIR##*/} ${0##*/}"
echo "  $WM_COMPILER ${WM_COMPILER_TYPE:-system} compiler [${WM_COMPILE_CONTROL}]"
echo "  ${WM_OPTIONS}, with ${WM_MPLIB} ${FOAM_MPI}"
echo ========================================
echo

# Compile tools for wmake
"${WM_DIR:-wmake}"/src/Allmake

# Compile ThirdParty libraries and applications
if [ -d "$WM_THIRD_PARTY_DIR" ]
then
    if [ -e "$WM_THIRD_PARTY_DIR"/Allwmake.override ]
    then
        if [ -x "$WM_THIRD_PARTY_DIR"/Allwmake.override ]
        then    "$WM_THIRD_PARTY_DIR"/Allwmake.override
        fi
    elif [ -x "$WM_THIRD_PARTY_DIR"/Allwmake ]
    then      "$WM_THIRD_PARTY_DIR"/Allwmake
    else
        echo "Skip ThirdParty (no Allwmake* files)"
    fi
else
    echo "Skip ThirdParty (no directory)"
fi

# OpenFOAM libraries
src/Allwmake $targetType $*

# OpenFOAM applications
applications/Allwmake $targetType $*


# Additional components/modules
case "$FOAM_MODULE_PREFIX" in
(false | none)
    echo ========================================
    echo "OpenFOAM modules disabled (prefix=${FOAM_MODULE_PREFIX})"
    echo
    ;;
(*)
    # Use wmake -all instead of Allwmake to allow for overrides
    ( cd "$WM_PROJECT_DIR/modules" 2>/dev/null && wmake -all )
esac

# Count files in given directory. Ignore "Test-*" binaries.
_foamCountDirEntries()
{
    (cd "$1" 2>/dev/null && find . -mindepth 1 -maxdepth 1 -type f 2>/dev/null) |\
        sed -e '\@/Test-@d' | wc -l
}

# Some summary information
echo
date "+%Y-%m-%d %H:%M:%S %z" 2>/dev/null || echo "date is unknown"
echo ========================================
echo "  ${WM_PROJECT_DIR##*/}"
echo "  $WM_COMPILER ${WM_COMPILER_TYPE:-system} compiler"
echo "  ${WM_OPTIONS}, with ${WM_MPLIB} ${FOAM_MPI}"
echo

# The api/patch information
sed -e 's/^/  /; s/=/ = /' ./META-INFO/api-info 2>/dev/null || true

echo "  bin = $(_foamCountDirEntries "$FOAM_APPBIN") entries"
echo "  lib = $(_foamCountDirEntries "$FOAM_LIBBIN") entries"
echo
echo ========================================

#------------------------------------------------------------------------------