{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    templates = {
      php56 = {
        description = "PHP 5.6 environment";
        path = "./php56";
      };
    };
  };
}
