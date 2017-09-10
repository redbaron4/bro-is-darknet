module Site;

export {
    # These should be figured out based on how large local_nets is
    # if local_nets is a single /24, v4_aggregation_bits can be 32
    const v4_aggregation_bits = 24 &redef;
    const v6_aggregation_bits = 64 &redef;

    global used_address_space: set[subnet] &synchronized &redef;
    global darknet_address_space: set[subnet] &synchronized &redef;
    global is_darknet: function(a: addr): bool;

    type DarknetMode: enum {
        DARKNET,
        NOT_ALLOCATED,
        DARKNET_OR_NOT_ALLOCATED,
        DARKNET_AND_NOT_ALLOCATED,
    };
    const darknet_mode: DarknetMode=DARKNET &redef;
}

function aggregate_address(a: addr): subnet
{
    if(is_v4_addr(a)) {
        return mask_addr(a, v4_aggregation_bits);
    } else {
        return mask_addr(a, v6_aggregation_bits);
    }
}

function add_host(a: addr)
{
    if (a !in used_address_space) {
        local masked = aggregate_address(a);
        add used_address_space[masked];
        Reporter::info(fmt("New used address space %s", masked));
        flush_all();
    }
}

function is_darknet(a: addr): bool
{
    switch ( darknet_mode) {
    case DARKNET:
        return (a in darknet_address_space);
    case NOT_ALLOCATED:
        return (a in local_nets && a !in used_address_space);
    case DARKNET_OR_NOT_ALLOCATED:
        return (a in darknet_address_space || (a in local_nets && a !in used_address_space));
    case DARKNET_AND_NOT_ALLOCATED:
        return (a in darknet_address_space && (a in local_nets && a !in used_address_space));
    }
    Reporter::error(fmt("Invalid darknet_mode %s(%d)", darknet_mode, darknet_mode));
    return F;
}

#Similar to how known hosts works, but this will also catch udp only hosts.
event Conn::log_conn(rec: Conn::Info)
{
    if (|Site::local_nets| == 0)
        return;
    if (rec$local_orig && rec$orig_pkts > 0)
        add_host(rec$id$orig_h);
    if (rec$local_resp && rec$resp_pkts > 0)
        add_host(rec$id$resp_h);
}