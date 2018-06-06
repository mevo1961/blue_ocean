#!/usr/bin/env bash

################################################################################################
###
### Script to execute Coverity Tests either from the commandline or from Jenkins
###
### The script takes the following 4 parameters:
### - target_type          (FSM-r3|FSM-r4|Lionfish, default=FSM-r4)
### - module-list          (list containing one or more of ddal|kernelmodules, default=ddal)
###                        (please note that each module name must be identical to the name of the recipe
###                         used to build the module)
### - USE_COVERITY_CONNECT (y|n, default=n. Results are committed to the server only if set to y)
### - BRANCH_NAME          only needed if USE_COVERTIY_COONECT=y. The stream on the server is composed
###                        from BRANCH_NAME, module and target_type
###
### The following commands are valid calls of the script (list is not complete):
### - ./tools/coverity_scan_all.sh
###    (uses default parameters FSM-r4 ddal n)
### - ./tools/coverity_scan_all.sh FSM-r3 "ddal kernelmodules" y
###    (executes Coverity scan for FSM-r3, ddal and kernelmodules, and commits the results to the server)
### - ./tools/coverity_scan_all.sh Lionfish kernelmodules n
###    (executes Coverity scan for Lionfish kernelmodules, but does not commit to the server
### - ...
################################################################################################


set -aeu

## @fn      do_setup()
#  @brief   set the required variables to run a coverity test
#  @param   {target_type}  target_type to build, e.g. FSM-r3
#  @param   {module_list} the list of modules to be tested with Coverity, e.g. "ddal kernelmodules"
#  @param   {server} set to 'y' if results should be commited to server
#  @return  <none>
do_setup()
{
    local target_type="${1:-FSM-r4}"
    # COVERITY_INSTALLATION_PATH will be set in Jenkins global variables
    COV_INSTALL_DIR=${COVERITY_INSTALLATION_PATH:-"/opt/coverity/x86_64/8.7.1"}
    COV_ROOTDIR=$(pwd)
    COV_WORKDIR="$COV_ROOTDIR/COV_WORKDIR"
    COV_CONFIG_DIR="$COV_WORKDIR"
    COV_RESULTS_DIR="$COV_WORKDIR/coverity-results/$target_type"
    COV_REPORT_DIR="$COV_WORKDIR/coverity-report/$target_type/html"
    COV_CONFIG="$COV_CONFIG_DIR/coverity-config.xml"
    COV_PREVIEW_PARSER="./tools/cov_commit_preview_parser.py"
    COV_ERRORS_PER_MODULE=""
    COV_TARGET=""
    BITBAKE_TARGET=""
    COV_MODULE="${2:-ddal}"
    COV_CONNECT_SERVER=escovsub1.emea.nsn-net.net
    COV_CONNECT_PORT=8080
    COV_CONNECT_HTTPS_PORT=8443
    COV_CONNECT_SERVER_TIMEOUT=1800
    COV_BUILD_TIMEOUT=1800
    COV_API_SERVER=135.3.26.236/~coverity/cgi-bin/cov_cids_report.pl
    COV_KEYFILE="$HOME/.coverity/authkeys/ak-escovsub1.emea.nsn-net.net-8080"
    USE_COVERITY_CONNECT="${3:-n}"
    BRANCH_NAME="${4:-master}"

    case $target_type in
        FSM-r3)
            COV_TARGET="mips64-octeon2-linux-gnu"
            BITBAKE_TARGET="fsmr3"
            ;;
        FSM-r4)
            COV_TARGET="arm-cortexa15-linux-gnueabihf"
            BITBAKE_TARGET="fsmr4-axm"
            ;;
        Lionfish)
            COV_TARGET="aarch64-linux-gnu"
            BITBAKE_TARGET="fsm-lionfish"
            ;;
        AirScale5G)
            COV_TARGET="x86_64-pc-linux-gnu" 
            BITBAKE_TARGET="airscale5g_xeon"
            ;;
        *)
            COV_TARGET="unknown_COV_TARGET"
            BITBAKE_TARGET="unknown_BITBAKE_TARGET"
            ;;
    esac

    COV_STREAM=${BRANCH_NAME}--${COV_MODULE}--${COV_TARGET}

    export PATH="$COV_INSTALL_DIR/bin:$PATH"

    # remove old report dir, otherwise Coverity will complain
    rm -rf  $COV_REPORT_DIR
    mkdir -p $COV_WORKDIR $COV_CONFIG_DIR $COV_RESULTS_DIR $COV_REPORT_DIR

    cov-configure --config $COV_CONFIG --compiler $COV_TARGET-gcc --comptype gcc --template
}

## @fn      build_cmd()
#  @brief   build command used to build a module. The name of the module(=recipe) must be stored in the variable $module
#  @param   {module} the module (= name of recipe) to be built e.g. "ddal"
#  @return  <none>
build_cmd()
{
    local module=$1
    case $module in
        ddal)           BITBAKE_BUILD="y" ;;
        kernel-modules) BITBAKE_BUILD="y" ;;
        *)              BITBAKE_BUILD="n" ;;
    esac
    if [[ ${BITBAKE_BUILD} == "y" ]]; then
        echo "#!/bin/bash"  > ./build_${module}.sh
        echo "make"
        chmod 777 ./build_${module}.sh
        echo "./build_${module}.sh"
    else
        echo "./build ${module} $COV_TARGET --dirty --force $@"
    fi
}

## @fn      run_coverity()
#  @brief   run a coverity test
#  @param   {module} the module to be tested with Coverity, e.g. "ddal"
#  @return  <none>
run_coverity()
{
    local module="$1"
    local results_dir="$COV_RESULTS_DIR/$module"
    local report_dir="$COV_REPORT_DIR/$module"
    local cov_strippath
    case $module in
        ddal)          BITBAKE_BUILD="y" ;;
        kernelmodules) BITBAKE_BUILD="y" ;;
        *)             BITBAKE_BUILD="n" ;;
    esac

    mkdir -p $results_dir $report_dir

    # make a first build to make sure that only the required module will be built during cov-build command below
    if [[ ${BITBAKE_BUILD} == "y" ]] ; then
        if [[ "${module}" == "kernelmodules" ]] ; then
            bbmodule='kernel-modules'
        else
            bbmodule="${module}"
        fi

        echo "building dependencies"
        bash -c ". ./env.sh ${BITBAKE_TARGET} && bitbake ${bbmodule}"
    else
        timeout -s 9 ${COV_BUILD_TIMEOUT} $(build_cmd $module)
    fi

    # now build and analyze module with Coverity
    if [[ ${BITBAKE_BUILD} == "y" ]]; then
        if [[ "${module}" == "kernelmodules" ]] ; then
            bbmodule='kernel-modules'
        else
            bbmodule="${module}"
        fi

        if [[ "${USE_COVERITY_CONNECT}" == "y" ]] ; then
            # only do this if called from Jenkins:
            # make a dummy commit to force building during the following cov_build command
            echo executing dummy commit to force bitbake to build ${module}
            cd src/${module}
            git commit --allow-empty -m 'dummy commit to force building of submodule'
            cd -
        fi

        echo now building with command: cov-build --config $COV_CONFIG --dir "$results_dir" $(build_cmd ${bbmodule})
        # should be executed with a timeout, but somehow this does not work with bitbake
        cov-build --config $COV_CONFIG --dir "$results_dir" $(build_cmd ${bbmodule})
    else
        # make sure that module is really built (i.e. make it "dirty")
        touch "${COV_ROOTDIR}/src/$module/.dirty"
        echo "now building with command $(build_cmd $module)"

        timeout -s 9 ${COV_BUILD_TIMEOUT} cov-build --config $COV_CONFIG --dir "$results_dir" $(build_cmd $module --nodeps)
        # make module source dir clean again
        rm "${COV_ROOTDIR}/src/$module/.dirty"
    fi
    cov_strippath="$COV_ROOTDIR/builds/$COV_TARGET/$module/"
    cov-analyze --all --dir "$results_dir"  --strip-path="$cov_strippath"


    # commit the results (if required) and represent them as html
    if [[ ${USE_COVERITY_CONNECT} == "y" ]] ; then
        # the following stream must exist on the Connect Server. If it does not exist yet, create it:
        # go to https://escovsub1.emea.nsn-net.net:8443, then "Configuration" (top on the right side) - "Projects & Streams"

        if check_committing_necessary ; then
            # commit to server with given timeout
            echo now committing data to server ...
            timeout -s 9 ${COV_CONNECT_SERVER_TIMEOUT} cov-commit-defects --ssl --on-new-cert trust --auth-key-file "$COV_KEYFILE" --dir "$results_dir" --host "$COV_CONNECT_SERVER" --https-port ${COV_CONNECT_HTTPS_PORT} --stream "$COV_STREAM" --scm git
        fi
        curl -s -S -o "$report_dir/index.html" "http://$COV_API_SERVER?req=show_cids&parms=cov_parms_espoo&mode=stream&name=${COV_STREAM}&comp=all&status=both"
        COV_ERRORS_PER_MODULE="$COV_ERRORS_PER_MODULE $module:"$(cov_connect_errors_num "$report_dir")
    else
        cov-format-errors --dir "$results_dir" --html-output "$report_dir" --strip-path="$cov_strippath"
        COV_ERRORS_PER_MODULE="$COV_ERRORS_PER_MODULE $module:"$(cov_errors_num "$report_dir")
        cp -f "$COV_INSTALL_DIR/dtd/config.dtd" "$report_dir"
    fi
}

## @fn      cov_errors_num()
#  @brief   retrieve the total number of errors from the coverity summary.xml file
#  @param   {summary} path to the summary.xml file
#  @return  <none>
cov_errors_num()
{
    local summary="$1/summary.xml"
    [[ -e "$summary" ]] || { echo "unknown"; return; }
    echo $(grep -A 10 "Total" "$summary" | egrep "<num>[0-9]+" | sed 's:</*num>::g')
}

## @fn      cov_cids_report_filter()
#  @brief   filter the number of errors from the given html file for the given keyword
#  @param   {index}   path to the index.html file
#  @param   {keyword} keyword ('new' or 'outstanding') to search for
#  @return  <none>
cov_cids_report_filter()
{
    local index="$1"
    local keyword="$2"
    echo $(egrep -o 'Summary Report: '$keyword' defects(<[/a-z]+>)+Total(<[/a-z]+>)+[0-9]+' "$index" | egrep -o '[0-9]+$')
}


## @fn      coverity_connect_errors_num()
#  @brief   retrieve the number of new and outstanding errors from the coverity index.html file
#  @param   {index} path to the index.html file
#  @return  <none>
cov_connect_errors_num()
{
    local index="$1/index.html"
    [[ -e "$index" ]] || { echo "unknown"; return; }
    echo $(cov_cids_report_filter "$index" "new")":"$(cov_cids_report_filter "$index" "outstanding")
}

## @fn      create_index_html()
#  @brief   create an index.html file for the coverity results
#  @param   {errors_per_module} string containing the number of errors per module
#  @return  <none>
create_index_html()
{
    local html_file="$COV_REPORT_DIR/index.html"
    local errors_per_module=$*

    echo Now creating index file "$COV_REPORT_DIR/index.html"

cat >"$html_file" <<'EOF'
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<title>Coverity Results</title>
</head>
<body bgcolor="#FFFFFF" text="#000000" link="#37598D" vlink="#5685AB">
<center><h2>Coverity results per module</h2></center>
<center><p>(Click on link for details)</center>
<ul>
EOF

    local footer=""
    local module
    for module in $errors_per_module
    do
        local modinfo=(${module//:/ })
        if [[ "${USE_COVERITY_CONNECT}" == "y" ]] ; then
            local hl_b=""
            local hl_e=""
            footer='<p><center><font size=-1><a href="https://escovsub1.emea.nsn-net.net:8443/">Coverity Connect</a></font></center>'
            [[ ${#modinfo[@]} -gt 2 ]] || continue
            if [ ${modinfo[1]} -gt 0 ] ; then
                hl_b="<font color=red>"
                hl_e="</font>"
            fi
            echo "<a href=\"${modinfo[0]}/index.html\"><b>${modinfo[0]}</b></a> : ${hl_b}${modinfo[1]} New${hl_e} (${modinfo[2]} Outstanding)<br>" >> "$html_file"
        else
            [[ ${#modinfo[@]} -gt 1 ]] || continue
            echo "<a href=\"${modinfo[0]}/index.html\"><b>${modinfo[0]}</b></a> : ${modinfo[1]} Errors<br>" >> "$html_file"
        fi
    done

    echo -e "</ul>\n${footer}\n</body>\n</html>" >> "$html_file"
}

## @fn      check_committing_necessary()
#  @brief   check if either new defects were found or previously existing defects were fixed
#  @param   <none>
#  @return  <none>
check_committing_necessary()
{
    local defects_file=defects.txt
    local new_cid_file=new_cids.txt
    local preview_file=commit_preview.txt
    local resval=1

    # get current defects from coverity DB
    cov-manage-im --ssl --on-new-cert trust --auth-key-file "$COV_KEYFILE" --host ${COV_CONNECT_SERVER} --port ${COV_CONNECT_HTTPS_PORT} --mode defects --show --stream $COV_STREAM --fields cid,checker,status,classification > $defects_file

    ISSUES_IN_DATABASE=$(($(wc -l < $defects_file) - 1))
    echo found ${ISSUES_IN_DATABASE} issues in database

    # create a preview of defects in current workspace
    cov-commit-defects --ssl --on-new-cert trust --auth-key-file "$COV_KEYFILE" --dir "$results_dir" --host ${COV_CONNECT_SERVER} --https-port ${COV_CONNECT_HTTPS_PORT} --stream $COV_STREAM --preview-report-v2 $preview_file


    ISSUES_IN_CURRENT_ANALYSIS=$(grep -c '"cid" :' ${preview_file})
    echo found ${ISSUES_IN_CURRENT_ANALYSIS} issues in current analysis

    # scan preview file for new defects
    python $COV_PREVIEW_PARSER $preview_file -o $new_cid_file

    NEW_CID_COUNT=$(wc -l < $new_cid_file)
    if [[ ${NEW_CID_COUNT} -gt 0 ]] ; then
        echo "New defects found, total new CIDS=${NEW_CID_COUNT}. Committing to server necessary"
        resval=0
    elif [[ ${ISSUES_IN_CURRENT_ANALYSIS} -lt ${ISSUES_IN_DATABASE} ]] ; then
        echo some CIDs were fixed, committing to server necessary ...
        resval=0
    fi

    rm $defects_file $preview_file $new_cid_file
    return $resval
}

#----------------------------------------------------------------------------
# execution starts here
#----------------------------------------------------------------------------
do_setup "${1:-FSM-r4}" "${2:-ddal}"  "${3:-n}" "${4:-master}"

run_coverity $COV_MODULE

create_index_html $COV_ERRORS_PER_MODULE

exit 0
