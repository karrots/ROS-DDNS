#TODO
# Clean up old entries if computer name changes between binds.

# Domain to be added to your DHCP-clients hostname
:local topdomain;
:set topdomain "domain.name";

# Set TTL to use for DDNS entries
:local ttl;
:set ttl "00:10:00";

# Set variables to use
:local FQDN;
:local isFree;

# Host validation string used to distinguish DDNS entries from static.
# Also used to tie entries to certian MAC addresses to avoid collisions. Fir
:local hostvalidationtoken;
:set hostvalidationtoken ("auto-" . $leaseActMAC . "-" . $leaseServerName);

# Test if this is a bind or unbind of the lease. If bind proceed with creating DDNS entry.
:if ($leaseBound=1) do={
	:log debug ("Processing bound lease " . $leaseActMAC . " - " .$leaseActIP . " server: " . $leaseServerName);
	/ip dhcp-server lease;
# Test for host name in lease. If exists continue with script.
	:if ([:len [get [find where active-mac-address=$leaseActMAC] host-name]] > 0) do={

# Set the isFree test variable to true. Assemble the DNS entry to be created later.
		:set isFree "true";
# dirtyHostname comed from client DHCP request which can contain spaces
# cleanHostname is cleaned from those whitsepace
		:local dirtyHostname [get [find where active-mac-address=$leaseActMAC] host-name];
		:local cleanHostname "";
		:for i from=0 to=([:len $dirtyHostname ]-1) do={ :local tmp [:pick $dirtyHostname  $i];
			:if ($tmp !=" ") do={ :set cleanHostname  "$cleanHostname$tmp" } 
		}
		:set FQDN ($cleanHostname . "." . $topdomain);
		
# Check if the DNS entry exists already. Then verify we are not about to over write
# another entry that isn't ours. Test using the $hostvalidationtoken
		/ip dns static;
		:if ([print count-only where name=$FQDN] > 0) do={
# Is it the same host as before?		 
			:if ([get [find where name=$FQDN] comment] = $hostvalidationtoken ) do={
# Looks like it is. Check if IP changed and update entry if so.
				:if ([get [find where name=$FQDN] address] != $leaseActIP) do={
# Update existing entry
					:log info ("Updating DDNS entry for: " . $FQDN . " to: ". $leaseActIP);
					/ip dns static set [find where name=$FQDN] address=$leaseActIP ttl=$ttl;
					:set isFree "false";
					}
			} else={
# No existing entry is static. Don't update.
				:set isFree "false";
				:put ("Not adding already existing entry: " . $FQDN);
			}
		}
# Add entry if no previous entry
		:if ($isFree = true) do={
		:log info ("Adding DDNS entry: " . $FQDN . " : " . $leaseActIP . " MAC: ". $leaseActMAC ) ;
		/ip dns static add name=$FQDN address=$leaseActIP ttl=$ttl comment=$hostvalidationtoken;
		}
	}
} else={
# Remove entry when lease expires. $leaseBound=0
	:log debug ("Processing deassigned lease " . $leaseActMAC . " - " .$leaseActIP . " server: " . $leaseServerName);
	/ip dns static;
	:if ( [print count-only where comment=$hostvalidationtoken] > 0) do={
		:set FQDN ([get [find where comment=$hostvalidationtoken] name ]);
		/ip dns static remove [find where comment=$hostvalidationtoken];
		:log info ("Remove DDNS entry " . $FQDN . " - " .$leaseActIP . " MAC: " . $leaseActMAC);
	};
};
