package cloudstack

import (
	"fmt"

	"github.com/go-ini/ini"
	"github.com/hashicorp/terraform/helper/schema"
	"github.com/hashicorp/terraform/terraform"
)

// Provider returns a terraform.ResourceProvider.
func Provider() terraform.ResourceProvider {
	return &schema.Provider{
		Schema: map[string]*schema.Schema{
			"api_url": &schema.Schema{
				Type:          schema.TypeString,
				Optional:      true,
				DefaultFunc:   schema.EnvDefaultFunc("CLOUDSTACK_API_URL", nil),
				ConflictsWith: []string{"config", "profile"},
			},

			"api_key": &schema.Schema{
				Type:          schema.TypeString,
				Optional:      true,
				DefaultFunc:   schema.EnvDefaultFunc("CLOUDSTACK_API_KEY", nil),
				ConflictsWith: []string{"config", "profile"},
			},

			"secret_key": &schema.Schema{
				Type:          schema.TypeString,
				Optional:      true,
				DefaultFunc:   schema.EnvDefaultFunc("CLOUDSTACK_SECRET_KEY", nil),
				ConflictsWith: []string{"config", "profile"},
			},

			"config": &schema.Schema{
				Type:          schema.TypeString,
				Optional:      true,
				ConflictsWith: []string{"api_url", "api_key", "secret_key"},
			},

			"profile": &schema.Schema{
				Type:          schema.TypeString,
				Optional:      true,
				ConflictsWith: []string{"api_url", "api_key", "secret_key"},
			},

			"http_get_only": &schema.Schema{
				Type:        schema.TypeBool,
				Required:    true,
				DefaultFunc: schema.EnvDefaultFunc("CLOUDSTACK_HTTP_GET_ONLY", false),
			},

			"timeout": &schema.Schema{
				Type:        schema.TypeInt,
				Required:    true,
				DefaultFunc: schema.EnvDefaultFunc("CLOUDSTACK_TIMEOUT", 900),
			},
		},

		ResourcesMap: map[string]*schema.Resource{
			"cloudstack_affinity_group":       resourceCloudStackAffinityGroup(),
			"cloudstack_disk":                 resourceCloudStackDisk(),
			"cloudstack_egress_firewall":      resourceCloudStackEgressFirewall(),
			"cloudstack_firewall":             resourceCloudStackFirewall(),
			"cloudstack_instance":             resourceCloudStackInstance(),
			"cloudstack_ipaddress":            resourceCloudStackIPAddress(),
			"cloudstack_loadbalancer_rule":    resourceCloudStackLoadBalancerRule(),
			"cloudstack_network":              resourceCloudStackNetwork(),
			"cloudstack_network_acl":          resourceCloudStackNetworkACL(),
			"cloudstack_network_acl_rule":     resourceCloudStackNetworkACLRule(),
			"cloudstack_nic":                  resourceCloudStackNIC(),
			"cloudstack_port_forward":         resourceCloudStackPortForward(),
			"cloudstack_private_gateway":      resourceCloudStackPrivateGateway(),
			"cloudstack_secondary_ipaddress":  resourceCloudStackSecondaryIPAddress(),
			"cloudstack_security_group":       resourceCloudStackSecurityGroup(),
			"cloudstack_security_group_rule":  resourceCloudStackSecurityGroupRule(),
			"cloudstack_ssh_keypair":          resourceCloudStackSSHKeyPair(),
			"cloudstack_static_nat":           resourceCloudStackStaticNAT(),
			"cloudstack_static_route":         resourceCloudStackStaticRoute(),
			"cloudstack_template":             resourceCloudStackTemplate(),
			"cloudstack_vpc":                  resourceCloudStackVPC(),
			"cloudstack_vpn_connection":       resourceCloudStackVPNConnection(),
			"cloudstack_vpn_customer_gateway": resourceCloudStackVPNCustomerGateway(),
			"cloudstack_vpn_gateway":          resourceCloudStackVPNGateway(),
		},

		ConfigureFunc: providerConfigure,
	}
}

func providerConfigure(d *schema.ResourceData) (interface{}, error) {
	apiURL := d.Get("api_url").(string)
	apiKey := d.Get("api_key").(string)
	secretKey := d.Get("secret_key").(string)

	if configFile, ok := d.GetOk("config"); ok {
		config, err := ini.Load(configFile.(string))
		if err != nil {
			return nil, err
		}

		section, err := config.GetSection(d.Get("profile").(string))
		if err != nil {
			return nil, err
		}

		apiURL = section.Key("url").String()
		apiKey = section.Key("apikey").String()
		secretKey = section.Key("secretkey").String()
	}

	if apiURL == "" || apiKey == "" || secretKey == "" {
		return nil, fmt.Errorf("No api_url or api_key or secretKey provided")
	}

	config := Config{
		APIURL:      apiURL,
		APIKey:      apiKey,
		SecretKey:   secretKey,
		HTTPGETOnly: d.Get("http_get_only").(bool),
		Timeout:     int64(d.Get("timeout").(int)),
	}

	return config.NewClient()
}