module github.com/squat/terraform-provider-vultr

go 1.12

replace github.com/JamesClonk/vultr => ./vendor/github.com/JamesClonk/vultr

require (
	github.com/JamesClonk/vultr v2.0.1+incompatible
	github.com/hashicorp/terraform v0.12.3
)
