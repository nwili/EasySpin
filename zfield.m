% zfield  Electronic zero field interaction Hamiltonian 
%
%   F = zfield(SpinSystem)
%   F = zfield(SpinSystem,Electrons)
%   F = zfield(SpinSystem,Electrons,'sparse')
%
%   Returns the electronic zero-field interaction (ZFI)
%   Hamiltonian [MHz] of the system SpinSystem.
%
%   If the vector Electrons is given, the ZFI of only the
%   specified electrons is returned (1 is the first, 2 the
%   second, etc). Otherwise, all electrons are included.
%
%   If 'sparse' is given, the matrix is returned in sparse format.

function H = zfield(SpinSystem,Electrons,opt)

if (nargin==0), help(mfilename); return; end

[Sys,err] = validatespinsys(SpinSystem);
error(err);

if (nargin<2), Electrons = []; end
if (nargin<3), opt = ''; end
if ~ischar(opt)
  error('Third input must be a string, ''sparse''.');
end
sparseResult = strcmp(opt,'sparse');

if isempty(Electrons), Electrons = 1:Sys.nElectrons; end

if any(Electrons>Sys.nElectrons) || any(Electrons<1),
  error('Electron spin index/indices (2nd argument) out of range!');
end

H = sparse(Sys.nStates,Sys.nStates);
spvc = Sys.Spins;

for e = 1:length(Electrons)
  
  idx = Electrons(e);

  % S or I < 1 -> no internal interactions possible -> go to next spin
  if spvc(idx)<1, continue; end
  
  % Quadratic term S*D*S
  %----------------------------------------------------------
  % Prepare full D matrix
  if Sys.fullD
    D = Sys.D(3*(idx-1)+(1:3),:);
  else
    Ddiag = Sys.D(idx,:);
    if any(Ddiag)
      Rp = erot(Sys.Dpa(idx,:));
      D = Rp*diag(Ddiag)*Rp.';
    else
      D = 0;
    end
  end
  if any(D(:))
    % Construct spin operator matrices
    for c = 3:-1:1
      so{c} = sop(spvc,idx,c,'sparse');
    end
    % Construct SDS term
    for c1 = 1:3
      for c2 = 1:3
        H = H + D(c1,c2)*(so{c1}*so{c2});
      end
    end
  end

  % Fourth-order terms a and F
  %---------------------------------------------------------
  % Abragam/Bleaney p. 142, 437
  % Bleaney/Trenam, Proc Roy Soc A, 223(1152), 1-14, (1954)
  % Doetschman/McCool, Chem Phys 8, 1-16 (1975)
  % Scullane, JMR 47, 383 (1982)
  % Jain/Lehmann, phys.stat.sol.(b) 159, 495 (1990)

  if isfield(Sys,'aF')
    % work only for first electron spin
    if (idx~=1)
      continue;
    end
    % not available if D frame is tilted (would necessitate rotation
    % of the a and F terms which is not implemented).
    if isfield(Sys,'Dpa')
      if ~isempty(Sys.Dpa) && any(Sys.Dpa)
        error('It''s not possible to use Sys.aF with a tilted D frame (Sys.Dpa).');
      end
    end
    S = spvc(1);
    n = S*(S+1);
    Sz = sop(spvc,1,3,'sparse');
    O40 = (35*Sz^4-30*n*Sz^2+25*Sz^2-(6*n-3*n^2)*speye(length(Sz)));
    F = Sys.aF(2);
    if (F~=0)
      H = H + (F/180)*O40;
    end
    a = Sys.aF(1);
    if (a~=0)
      Sp = sop(spvc,1,4,'sparse');
      Sm = sop(spvc,1,5,'sparse');
      if ~isfield(Sys,'aFrame'), Sys.aFrame = 4; end
      if (Sys.aFrame==3)
        % along threefold axis (see Abragam/Bleaney p.142, p.437)
        O43 = (Sz*(Sp^3+Sm^3)+(Sp^3+Sm^3)*Sz)/2;
        H = H - 2/3*(a/120)*(O40 + 10*sqrt(2)*O43);
      elseif (Sys.aFrame==4)
        % along fourfold (tetragonal) axis (used by some)
        O44 = (Sp^4+Sm^4)/2;
        H = H + (a/120)*(O40 + 5*O44);
      else
        error('Unknown Sys.aFrame value. Use 3 for trigonal and 4 for tetragonal (collinear with D).');
      end
    end
  end

  % High-order terms in extended Stevens operator format
  %---------------------------------------------------------
  % B1, B2, B3, ... (k = 1...12)
  
  % If D and aF are used, skip corresponding Stevens operator terms
  D_present = any(Sys.D(idx,:));
  aF_present = isfield(Sys,'aF');

  % Issue error when obsolete pre-4.5.2 syntax is used
  for k = 2:2:6
    for q = 0:k
      fi = sprintf('B%d%d',k,abs(q));
      if isfield(Sys,fi)
        error('Sys.%s is no longer supported.\nUse Sys.B%d instead. See documentation for details.',fi,k);
      end
    end
  end
  
  % Run over all Bk (B1, B2, B3, B4, ...)
  for k = 0:12
    fieldname = sprintf('B%d',k);
    
    if ~isfield(Sys,fieldname), continue; end
    
    if D_present && (k==2), continue; end
    if aF_present && (k==4), continue; end
    
    Bk = Sys.(fieldname);
    if all(Bk==0), continue; end
    
    for q = k:-1:-k
      if Bk(e,k+1-q)==0, continue; end
      H = H + Bk(e,k+1-q)*stev(spvc,k,q,idx);
    end
    
  end

end % for all spins specified

H = (H+H')/2; % Hermitianise
if ~sparseResult
  H = full(H);
end

return
