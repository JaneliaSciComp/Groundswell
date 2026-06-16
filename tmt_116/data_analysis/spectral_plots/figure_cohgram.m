function [h,h_a]=figure_cohgram(t,f,C_mag,C_phase,...
                                t_lim,f_lim,...
                                title_str,...
                                C_mag_thresh)

% deal with arguments
if nargin<5 || isempty(t_lim)
  dt=(t(end)-t(1))/(length(t)-1);
  t_lim=[t(1)-dt/2 t(end)+dt/2];
end
if nargin<6 || isempty(f_lim)
  f_lim=[f(1) f(end)];
end
if nargin<7
  title_str='';
end
if nargin<8 || isempty(C_mag_thresh)
  C_mag_thresh=0;
end

% convert to complex coherence
C=C_mag.*exp(1i*C_phase);  

% do the cohereogram itself
h=figure;
h_a=axes;
plot_cohgram(t,f,C_mag,C_phase,...
             t_lim,f_lim,...
             title_str,...
             C_mag_thresh);

% draw the colorbar
% the cohereogram itself is a truecolor image, so the axes colormap and
% CLim go unused by it; we repurpose them to drive the colorbar, which
% then shows the abs(C)==1 colors for every phase.  (We can't poke the
% colorbar's internal image directly: since R2014b colorbar returns a
% ColorBar object with no findable 'TMW_COLORBAR' child.)
cmap_phase=l75_border(256);  % to show abs(C)==1 colors
colormap(h_a,cmap_phase);
set(h_a,'CLim',[-180 +180]);
colorbar_axes_h=colorbar(h_a);
set(colorbar_axes_h,'YLim',[-180 +180]);
set(colorbar_axes_h,'YTick',[-180 -90 0 +90 +180]);
ylabel(colorbar_axes_h, 'Phase (deg), for |C|=1');
