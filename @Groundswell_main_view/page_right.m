function page_right(gsmv)

if ~isempty(gsmv.axes_hs)
  tl=gsmv.model.get_tl();
  tl_view=gsmv.tl_view;
  tw=tl_view(2)-tl_view(1);
  tf=tl(2);
  tl_view_new=tl_view+tw;
  if tl_view_new(2)>tf
    tl_view_new=[tf-tw tf];
  end
  gsmv.set_tl_view(tl_view_new);
end
