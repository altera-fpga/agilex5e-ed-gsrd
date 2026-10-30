# qsys_update.tcl shall performs IP upgrade on all .ips and .qsys files.
# Contrast this to quartus_sh --ip_upgrade will only update the required ip files.
# Example usage:
# qsys-script --qpf=top --script=qsys_update.tcl --system-file=qsys_top.qsys --search-path="custom_ip/**/*, $"

package require -exact qsys 25.1.1


reload_component_footprint
sync_sysinfo_parameters

save_system