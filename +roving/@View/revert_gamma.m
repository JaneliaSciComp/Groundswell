function revert_gamma(self)

cmap_name=self.cmap_name;
set(self.figure_h,'Colormap',roving.colormap_from_name(cmap_name));

end
