/* vi: set sw=4 ts=4: */
/*
 * cloud-init-networkcfg
 *
 * Parse a cloud-init network-config YAML file and extract the first
 * static IPv4 subnet. Prints shell-style KEY=VALUE lines for use by
 * init scripts.
 *
 * Licensed under GPLv2, see file LICENSE in this source tree.
 */
//config:config CLOUD_INIT_NETWORKCFG
//config:	bool "cloud-init-networkcfg (2 kb)"
//config:	default y
//config:	help
//config:	Parse a cloud-init network-config YAML file and emit
//config:	IP, GATEWAY, PREFIX and ONLINK as shell-style KEY=VALUE lines.

//applet:IF_CLOUD_INIT_NETWORKCFG(APPLET_ODDNAME(cloud-init-networkcfg, cloud_init_networkcfg, BB_DIR_USR_BIN, BB_SUID_DROP, cloud_init_networkcfg))

//kbuild:lib-$(CONFIG_CLOUD_INIT_NETWORKCFG) += cloud_init_networkcfg.o

//usage:#define cloud_init_networkcfg_trivial_usage
//usage:       "FILE"
//usage:#define cloud_init_networkcfg_full_usage "\n\n"
//usage:       "Parse cloud-init network-config YAML FILE and print\n"
//usage:       "IP, GATEWAY, PREFIX and ONLINK for the first static subnet"
//usage:
//usage:#define cloud_init_networkcfg_example_usage
//usage:       "$ cloud-init-networkcfg /run/cloud-init/network-config.yaml\n"
//usage:       "IP=154.17.19.222\n"
//usage:       "GATEWAY=193.41.250.250\n"
//usage:       "PREFIX=32\n"
//usage:       "ONLINK=onlink\n"

#include "libbb.h"

/* A valid IPv4 netmask is a contiguous run of 1 bits, so popcount == prefix. */
static int netmask_to_prefix(const char *mask)
{
	unsigned int a, b, c, d;
	if (sscanf(mask, "%u.%u.%u.%u", &a, &b, &c, &d) != 4)
		return 0;
	return __builtin_popcount((a << 24) | (b << 16) | (c << 8) | d);
}

/* Extract the value between the first pair of single quotes in `line`. */
static int extract_quoted(const char *line, char *out, int outsz)
{
	const char *p = strchr(line, '\'');
	const char *q;
	int len;

	if (!p)
		return 0;
	p++;
	q = strchr(p, '\'');
	if (!q)
		return 0;
	len = (int)(q - p);
	if (len >= outsz)
		len = outsz - 1;
	memcpy(out, p, len);
	out[len] = '\0';
	return 1;
}

/* True if `line` starts (after optional whitespace and a `-`) with `key`.
 * Handles "- type:", "-  type:", "  - type:", etc.
 */
static int starts_with_key(const char *line, const char *key)
{
	while (*line == ' ' || *line == '\t')
		line++;
	if (*line == '-') {
		line++;
		while (*line == ' ' || *line == '\t')
			line++;
	}
	return strncmp(line, key, strlen(key)) == 0;
}

int cloud_init_networkcfg_main(int argc, char **argv) MAIN_EXTERNALLY_VISIBLE;
int cloud_init_networkcfg_main(int argc, char **argv)
{
	FILE *fp;
	char line[128];
	char ip[32] = { 0 }, gw[32] = { 0 }, mask[32] = { 0 };
	int inside_static = 0;
	int prefix;
	const char *onlink;

	if (argc != 2)
		bb_show_usage();

	fp = fopen_or_warn(argv[1], "r");
	if (!fp)
		return EXIT_FAILURE;

	while (fgets(line, sizeof(line), fp)) {
		if (starts_with_key(line, "type:")) {
			if (inside_static && ip[0])
				break; /* done with static block */
			inside_static = (strstr(line, "static") != NULL);
			continue;
		}
		if (!inside_static)
			continue;
		if (strstr(line, "address:") && !ip[0])
			extract_quoted(line, ip, sizeof(ip));
		else if (strstr(line, "netmask:") && !mask[0])
			extract_quoted(line, mask, sizeof(mask));
		else if (strstr(line, "gateway:") && !gw[0])
			extract_quoted(line, gw, sizeof(gw));
	}
	fclose(fp);

	prefix = netmask_to_prefix(mask);
	onlink = (prefix == 32) ? "onlink" : "";
	printf("IP=%s\nGATEWAY=%s\nPREFIX=%d\nONLINK=%s\n", ip, gw, prefix, onlink);
	return EXIT_SUCCESS;
}
