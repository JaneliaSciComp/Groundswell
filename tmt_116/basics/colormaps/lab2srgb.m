function srgb = lab2srgb(lab)

srgb=xyz2srgb(lab2xyz(lab));
