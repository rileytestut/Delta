/*
 * Copyright (c) 1993, 1994, 1995, 1996, 1997
 *    The Regents of the University of California.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *    This product includes software developed by the Computer Systems
 *    Engineering Group at Lawrence Berkeley Laboratory.
 * 4. Neither the name of the University nor of the Laboratory may be used
 *    to endorse or promote products derived from this software without
 *    specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 */

#ifndef lib_pcap_h
#define lib_pcap_h

#include <sys/types.h>
#include <sys/time.h>

#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif
    
#define HOST_WINDOWS // Allow us to compile wifi.cpp without modifications.
    
#define PCAP_VERSION_MAJOR 2
#define PCAP_VERSION_MINOR 4
    
#define PCAP_ERRBUF_SIZE 256
    
    /*
     * Compatibility for systems that have a bpf.h that
     * predates the bpf typedefs for 64-bit support.
     */
#if BPF_RELEASE - 0 < 199406
    typedef    int bpf_int32;
    typedef    u_int bpf_u_int32;
#endif
    
    typedef struct pcap pcap_t;
    typedef struct pcap_dumper pcap_dumper_t;
    typedef struct pcap_if pcap_if_t;
    typedef struct pcap_addr pcap_addr_t;
    
    /*
     * The first record in the file contains saved values for some
     * of the flags used in the printout phases of tcpdump.
     * Many fields here are 32 bit ints so compilers won't insert unwanted
     * padding; these files need to be interchangeable across architectures.
     *
     * Do not change the layout of this structure, in any way (this includes
     * changes that only affect the length of fields in this structure).
     *
     * Also, do not change the interpretation of any of the members of this
     * structure, in any way (this includes using values other than
     * LINKTYPE_ values, as defined in "savefile.c", in the "linktype"
     * field).
     *
     * Instead:
     *
     *    introduce a new structure for the new format, if the layout
     *    of the structure changed;
     *
     *    send mail to "tcpdump-workers@tcpdump.org", requesting a new
     *    magic number for your new capture file format, and, when
     *    you get the new magic number, put it in "savefile.c";
     *
     *    use that magic number for save files with the changed file
     *    header;
     *
     *    make the code in "savefile.c" capable of reading files with
     *    the old file header as well as files with the new file header
     *    (using the magic number to determine the header format).
     *
     * Then supply the changes to "patches@tcpdump.org", so that future
     * versions of libpcap and programs that use it (such as tcpdump) will
     * be able to read your new capture file format.
     */
    struct pcap_file_header {
        bpf_u_int32 magic;
        u_short version_major;
        u_short version_minor;
        bpf_int32 thiszone;    /* gmt to local correction */
        bpf_u_int32 sigfigs;    /* accuracy of timestamps */
        bpf_u_int32 snaplen;    /* max length saved portion of each pkt */
        bpf_u_int32 linktype;    /* data link type (LINKTYPE_*) */
    };
    
    /*
     * Each packet in the dump file is prepended with this generic header.
     * This gets around the problem of different headers for different
     * packet interfaces.
     */
    struct pcap_pkthdr {
        struct timeval ts;    /* time stamp */
        bpf_u_int32 caplen;    /* length of portion present */
        bpf_u_int32 len;    /* length this packet (off wire) */
    };
    
    /*
     * As returned by the pcap_stats()
     */
    struct pcap_stat {
        u_int ps_recv;        /* number of packets received */
        u_int ps_drop;        /* number of packets dropped */
        u_int ps_ifdrop;    /* drops by interface XXX not yet supported */
    };
    
    /*
     * Item in a list of interfaces.
     */
    struct pcap_if {
        struct pcap_if *next;
        char *name;        /* name to hand to "pcap_open_live()" */
        char *description;    /* textual description of interface, or NULL */
        struct pcap_addr *addresses;
        u_int flags;        /* PCAP_IF_ interface flags */
    };
    
#define PCAP_IF_LOOPBACK    0x00000001    /* interface is loopback */
    
    /*
     * Representation of an interface address.
     */
    struct pcap_addr {
        struct pcap_addr *next;
        struct sockaddr *addr;        /* address */
        struct sockaddr *netmask;    /* netmask for that address */
        struct sockaddr *broadaddr;    /* broadcast address for that address */
        struct sockaddr *dstaddr;    /* P2P destination address for that address */
    };
    
    typedef void (*pcap_handler)(u_char *, const struct pcap_pkthdr *,
                                 const u_char *);
    
    char    *pcap_lookupdev(char *);
    int    pcap_lookupnet(char *, bpf_u_int32 *, bpf_u_int32 *, char *);
    pcap_t    *pcap_open_live(char *, int, int, int, char *);
    pcap_t    *pcap_open_dead(int, int);
    pcap_t    *pcap_open_offline(const char *, char *);
    void    pcap_close(pcap_t *);
    int    pcap_loop(pcap_t *, int, pcap_handler, u_char *);
    int    pcap_dispatch(pcap_t *, int, pcap_handler, u_char *);
    const u_char*
    pcap_next(pcap_t *, struct pcap_pkthdr *);
    int    pcap_stats(pcap_t *, struct pcap_stat *);
    int    pcap_setfilter(pcap_t *, struct bpf_program *);
    int    pcap_getnonblock(pcap_t *, char *);
    int    pcap_setnonblock(pcap_t *, int, char *);
    void    pcap_perror(pcap_t *, char *);
    char    *pcap_strerror(int);
    char    *pcap_geterr(pcap_t *);
    int    pcap_compile(pcap_t *, struct bpf_program *, char *, int,
                        bpf_u_int32);
    int    pcap_compile_nopcap(int, int, struct bpf_program *,
                               char *, int, bpf_u_int32);
    void    pcap_freecode(struct bpf_program *);
    int    pcap_datalink(pcap_t *);
    int    pcap_snapshot(pcap_t *);
    int    pcap_is_swapped(pcap_t *);
    int    pcap_major_version(pcap_t *);
    int    pcap_minor_version(pcap_t *);
    
    /* XXX */
    FILE    *pcap_file(pcap_t *);
    int    pcap_fileno(pcap_t *);
    
    pcap_dumper_t *pcap_dump_open(pcap_t *, const char *);
    void    pcap_dump_close(pcap_dumper_t *);
    void    pcap_dump(u_char *, const struct pcap_pkthdr *, const u_char *);
    
    int    pcap_findalldevs(pcap_if_t **, char *);
    void    pcap_freealldevs(pcap_if_t *);
    
    /* XXX this guy lives in the bpf tree */
    u_int    bpf_filter(struct bpf_insn *, u_char *, u_int, u_int);
    int    bpf_validate(struct bpf_insn *f, int len);
    char    *bpf_image(struct bpf_insn *, int);
    void    bpf_dump(struct bpf_program *, int);
    
#ifdef __cplusplus
}
#endif

#endif
