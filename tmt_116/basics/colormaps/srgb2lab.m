function lab = srgb2lab(srgb)

lab=xyz2lab(srgb2xyz(srgb));
