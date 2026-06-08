function Y = l2y(L)

% Handle a scalar input on its own: the vectorized path below uses logical
% indexing (L_prime(low)), which doesn't carry over cleanly when a 1x1 value
% has been reduced to a bare scalar, so compute the scalar case directly.
if isscalar(L)
  L_prime=(L+16)/116;
  if L_prime<=0.206893
    Y=(L_prime-16/116)/7.787;
  else
    Y=L_prime.^3;
  end
  return;
end

L_prime=(L+16)/116;
low=(L_prime<=0.206893);
high=~low;
Y=zeros(size(L_prime));
Y(low)=(L_prime(low)-16/116)/7.787;
Y(high)=L_prime(high).^3;
