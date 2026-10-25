#!/bin/bash
# v2: physical-aware (PLE) synthesis + clock-period sweep + hold report.
#
#   cd syn/genus && nohup bash run_genus.sh > run.log 2>&1 &   # background run
#   tail -f run.log                                            # watch progress
#
# Results: out_v2/SUMMARY.txt and out_v2/<run>/ (area, gates, timing, hold, qor,
#          power, netlist, genus.log)
#
# Steps
#   1. smoke         adder8 with PLE (must pass)
#   2. pipe_5.0      final design, 5.0 ns  \  same constraint -> fair area and
#      unpipe_5.0    original datapath     /  critical-path comparison
#   3. sweep         each variant re-synthesized at tighter periods until the
#                    worst setup slack goes negative -> measured minimum period

set -u
cd "$(dirname "$0")"
ROOT=$PWD
RTL=$(cd "$ROOT/../../rtl" && pwd)
OUT=$ROOT/out_v2

GENUS=${GENUS:-/tools/cadence/DDI251/GENUS251/bin/genus}
LIB=${LIB:-/tools/PDK/NCSU45PDK/FreePDK45/osu_soc/lib/files/gscl45nm.lib}
LEF=${LEF:-/tools/PDK/NCSU45PDK/FreePDK45/osu_soc/lib/files/gscl45nm.lef}
SWEEP=${SWEEP:-"4.75 4.5 4.25 4.0 3.75 3.5 3.25 3.0 2.75 2.5 2.25 2.0 1.75 1.5"}
LOAD_FF=50

# ---- environment -------------------------------------------------------------
if ! type module >/dev/null 2>&1; then
    for f in /etc/profile.d/modules.sh /usr/share/Modules/init/bash /etc/profile.d/lmod.sh; do
        [ -f "$f" ] && source "$f" && break
    done
fi
module load innovus/DDI251 >/dev/null 2>&1 || echo "WARNING: 'module load innovus/DDI251' failed"

for f in "$GENUS" "$LIB" "$LEF"; do [ -e "$f" ] || { echo "FAIL: not found: $f"; exit 1; }; done

unit_line=$(grep -m1 -i 'capacitive_load_unit' "$LIB")
case "$unit_line" in
    *ff*|*FF*) LOAD=$LOAD_FF ;;
    *pf*|*PF*) LOAD=$(awk "BEGIN{print $LOAD_FF/1000}") ;;
    *)         echo "FAIL: cannot read capacitive_load_unit ($unit_line)"; exit 1 ;;
esac

mkdir -p "$OUT"
LIBCELLS=$OUT/libcells.txt
grep -oE '^\s*cell\s*\(\s*"?[A-Za-z0-9_]+' "$LIB" | sed -E 's/.*\(\s*"?//' | sort -u > "$LIBCELLS"
echo "Library: $LIB ($(wc -l < "$LIBCELLS") cells), $unit_line -> set_load $LOAD"
echo "LEF:     $LEF"
echo "Started: $(date)"

# ---- helpers -----------------------------------------------------------------
filelist() {   # filelist <out> <rtl dir> [override files...]
    local f=$1 dir=$2; shift 2
    : > "$f"
    for m in UART_tx telemetry incline_sat desiredDrive inertial_integrator cadence_filt cadence_meas \
             cadence_LU PWM SPI_mnrch PID nonoverlap brushless mtr_drv A2D_intf inert_intf \
             reset_synch PB_rise PB_intf sensorCondition eBike; do
        local p=$dir/$m.sv
        for o in "$@"; do [ "$(basename "$o")" = "$m.sv" ] && p=$o; done
        echo "$p" >> "$f"
    done
}
make_sdc() {   # make_sdc <period> <out>
    sed -e "s/@PERIOD@/$1/" -e "s/@LOAD@/$LOAD/" "$ROOT/scripts/eBike.sdc.tpl" > "$2"
}
worst_slack() {   # first (worst) setup slack in ps from timing.rpt
    awk '/Slack:=/{print $2; exit}' "$1" 2>/dev/null
}

# run_synth <name> <top> <filelist> <sdc>   -> 0 = PASS
run_synth() {
    local name=$1 top=$2 flist=$3 sdc=$4
    local out=$OUT/$name
    rm -rf "$out"; mkdir -p "$out"
    echo
    echo "=== [$name] $(date +%H:%M:%S)"
    MODE=ple LEF=$LEF LIB=$LIB TOP=$top FILELIST=$flist SDC=$sdc OUT_DIR=$out \
        "$GENUS" -no_gui -batch -f "$ROOT/scripts/synth.tcl" > "$out/genus.log" 2>&1
    local rc=$? ok=1
    [ $rc -eq 0 ]                                       || { echo "  FAIL: Genus exit code $rc"; ok=0; }
    grep -q '^GENUS_SYNTH_DONE' "$out/genus.log"        || { echo "  FAIL: did not finish ($(grep -m1 GENUS_FAIL "$out/genus.log"))"; ok=0; }
    grep -q '^INTERCONNECT_MODE=ple' "$out/genus.log"   || { echo "  FAIL: PLE was not active ($(grep -m1 INTERCONNECT_MODE "$out/genus.log"))"; ok=0; }
    # Errors outside the OPTIONAL_BEGIN/END block (failed attempts at optional reports are expected)
    local errs
    errs=$(awk '/^OPTIONAL_BEGIN/{s=1} /^OPTIONAL_END/{s=0; next} !s' "$out/genus.log" | grep -E '^\s*(Error|ERROR)')
    if [ -n "$errs" ]; then
        echo "  FAIL: errors in log:"; echo "$errs" | head -5 | sed 's/^/    /'; ok=0
    fi
    for rpt in area.rpt timing.rpt; do [ -s "$out/$rpt" ] || { echo "  FAIL: $rpt missing"; ok=0; }; done
    local net=$out/${top}_mapped.v
    if [ -s "$net" ]; then
        local mods types bad
        mods=$(grep -oE '^\s*module\s+[A-Za-z0-9_$\\]+' "$net" | awk '{print $2}' | sort -u)
        types=$(grep -oE '^\s+[A-Za-z_][A-Za-z0-9_$]*\s+[A-Za-z_\\][^ ]*\s*\(' "$net" | awk '{print $1}' \
                | grep -vE '^(input|output|inout|wire|reg|assign|module|endmodule)$' | sort -u)
        bad=$(comm -23 <(echo "$types") <( (cat "$LIBCELLS"; echo "$mods") | sort -u) | grep -v '^$')
        [ -z "$bad" ] || { echo "  FAIL: unmapped cells: $(echo $bad | head -c 200)"; ok=0; }
    else
        echo "  FAIL: no netlist"; ok=0
    fi
    echo "  worst setup slack: $(worst_slack "$out/timing.rpt") ps"
    if [ $ok -eq 1 ]; then echo PASS > "$out/STATUS"; echo "  PASS"; return 0; fi
    echo FAIL > "$out/STATUS"; return 1
}

# ---- 1. smoke ----------------------------------------------------------------
echo "$ROOT/smoke/adder8.v" > "$OUT/smoke.f"
run_synth smoke adder8 "$OUT/smoke.f" "$ROOT/smoke/adder8.sdc" \
    || { echo; echo "PLE smoke test failed: stopping. Send out_v2/smoke/genus.log (tail -60)."; exit 1; }

# ---- 2. fair comparison at 5.0 ns ---------------------------------------------
filelist "$OUT/pipe.f"   "$RTL"
filelist "$OUT/unpipe.f" "$RTL" "$ROOT/variants/unpipelined/desiredDrive.sv"
make_sdc 5.0 "$OUT/sdc_5.0.sdc"
run_synth pipe_5.0   eBike "$OUT/pipe.f"   "$OUT/sdc_5.0.sdc"; r1=$?
run_synth unpipe_5.0 eBike "$OUT/unpipe.f" "$OUT/sdc_5.0.sdc"; r2=$?

# ---- 3. clock-period sweep -----------------------------------------------------
declare -A MINP
for v in pipe unpipe; do
    MINP[$v]="5.0"
    for p in $SWEEP; do
        make_sdc "$p" "$OUT/sdc_$p.sdc"
        if run_synth "${v}_$p" eBike "$OUT/$v.f" "$OUT/sdc_$p.sdc"; then
            s=$(worst_slack "$OUT/${v}_$p/timing.rpt")
            if [ -n "$s" ] && awk "BEGIN{exit !($s >= 0)}"; then
                MINP[$v]=$p
            else
                echo "  -> timing not met at $p ns, sweep for $v stops"; break
            fi
        else
            echo "  -> run failed at $p ns, sweep for $v stops"; break
        fi
    done
done

# ---- 4. summary ----------------------------------------------------------------
S=$OUT/SUMMARY.txt
{
    echo "Cadence Genus + OSU FreePDK45 (gscl45nm), physical-aware (PLE, LEF-based wire estimation)"
    echo "Finished $(date)"
    echo
    echo "=== Clock sweep: worst setup slack (ps) per period"
    printf "%-8s %12s %12s\n" period pipelined unpipelined
    for p in 5.0 $SWEEP; do
        a=$(worst_slack "$OUT/pipe_$p/timing.rpt");   [ -f "$OUT/pipe_$p/STATUS" ]   || a="-"
        b=$(worst_slack "$OUT/unpipe_$p/timing.rpt"); [ -f "$OUT/unpipe_$p/STATUS" ] || b="-"
        printf "%-8s %12s %12s\n" "$p" "${a:--}" "${b:--}"
    done
    echo
    echo "Smallest period with slack >= 0:  pipelined ${MINP[pipe]} ns   unpipelined ${MINP[unpipe]} ns"
    for r in smoke pipe_5.0 unpipe_5.0 "pipe_${MINP[pipe]}" "unpipe_${MINP[unpipe]}"; do
        [ -d "$OUT/$r" ] || continue
        echo
        echo "================ $r: $(cat "$OUT/$r/STATUS" 2>/dev/null)"
        echo "--- area"
        grep -A3 -E '^\s*Instance' "$OUT/$r/area.rpt" | head -4
        echo "--- worst setup path"
        grep -m4 -E 'Startpoint|Endpoint|Data Path|Slack' "$OUT/$r/timing.rpt"
        echo "--- worst hold path (ideal clock), $(grep -m1 '^HOLD_REPORT_CMD=' "$OUT/$r/genus.log")"
        if grep -q 'Slack' "$OUT/$r/hold.rpt" 2>/dev/null; then grep -m4 -E 'Startpoint|Endpoint|Data Path|Slack' "$OUT/$r/hold.rpt"; else echo "  $(head -1 "$OUT/$r/hold.rpt" 2>/dev/null)"; fi
        echo "--- qor"
        [ -f "$OUT/$r/qor.rpt" ] && grep -iE 'instance count|cell area|net area|total area' "$OUT/$r/qor.rpt" | head -8
        echo "--- power"
        [ -f "$OUT/$r/power.rpt" ] && grep -iE 'total|leakage|internal|switching' "$OUT/$r/power.rpt" | head -6
    done
} > "$S"
echo
cat "$S"
[ $r1 -eq 0 ] && [ $r2 -eq 0 ] && echo && echo "V2 DONE"
