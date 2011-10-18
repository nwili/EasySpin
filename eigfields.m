% eigfields  Resonance fields by the eigenfield method 
%
%   B = eigfields(Sys, Par,)
%   B = eigfields(Sys, Par, Opt)
%   [B, Int] = eigfields(...)
%
%   Calculates all resonance fields of spin system
%   Sys solving a generalized eigenvalue problem
%   in Liouville space together with transition pro-
%   babilitites.
%
%   Input:
%   - Sys: spin system specification structure
%   - Par: structure with fields
%        mwFreq - spectrometer frequency [GHz]
%        Mode - 'parallel' or 'perpendicular' (default)
%          direction of mirowave field relative to static field
%        Range - [Bmin Bmax] If set, compute only eigenfields
%           between Bmin and Bmax. [mT]
%         Ori: 2xn or 3xn array of orientation angles [radians]
%            columns contain [phi;theta] or [phi;theta;chi].
%            If chi is omitted, transition probabilities are
%            integrated over chi.
%   - Opt: options structure with fields
%        Threshold - if set, return only transitions with
%          relative intensity above Threshold. Works only if
%          transition intensities are returned.
%
%   Output:
%   - B:   cell array of all resonance fields [mT]
%   - Int: transition intensities [MHz^2/mT^2]

function varargout = eigfields(SpinSystem, Parameters, Options)

if (nargin==0), help(mfilename); return; end

% Uses generalised Liouville space eigenvalue problem
% formulation by Belford et al.

% Belford, Belford, Burkhalter, J.Magn.Reson. 11, 251-265 (1973)
% ATTENTION: different definition of direct product, hence change
% in the definition of A and B

% Check Matlab version.
error(chkmlver);

% Add empty Options structure if not specified.
switch nargin
case 3,
case 2, Options = [];
otherwise, error('Incorrect number of inputs!');
end

if isempty(Options)
  Options = struct('unused',NaN);
end

if ~(isstruct(SpinSystem) & isstruct(Parameters) & isstruct(Options))
  error('SpinSystem, Parameters and Options must be structures!');
end

% A global variable sets the level of log display. The global variable
% is used in logmsg(), which does the log display.
if ~isfield(Options,'Verbosity'), Options.Verbosity = 0; end
global EasySpinLogLevel;
EasySpinLogLevel = Options.Verbosity;

% Determine whether the caller wants intensities.
msg = 'positions';
switch nargout
case {0,1},
  ComputeIntensities = 0;
case 2,
  ComputeIntensities = 1;
  msg = [msg, ', intensities'];
otherwise,
  error('Incorrect number of output arguments!');
end
logmsg(1,'  computing %s',msg);

% Mute warnings because of unavoidable division by zero.
OldWarningState = warning('off');

% Process SpinSystem structure.
%===================================================================
[FSys,err] = validatespinsys(SpinSystem);
error(err);

% Process Parameter structure.
%===================================================================
if isfield(Parameters,'Detection')
  error('Exp.Detection is obsolete. Use Exp.Mode instead.');
end

DefaultParameters.mwFreq = NaN;
DefaultParameters.Range = [0 realmax];
DefaultParameters.Mode = 'perpendicular';
DefaultParameters.Temperature = inf; % not implemented!!
DefaultParameters.Orientations = NaN;

Parameters = adddefaults(Parameters,DefaultParameters);

if isnan(Parameters.mwFreq), error('Parameters.mwFreq missing!'); end
if isnan(Parameters.Orientations), error('Parameters.Orientations missing.'); end

if (diff(Parameters.Range)<=0) | ~isfinite(Parameters.Range) | ...
   ~isreal(Parameters.Range) | any(Parameters.Range<0) | (numel(Parameters.Range)~=2)
  error('Parameters.Range is not valid!');
end

ParallelMode = (2==parseoption(Parameters,'Mode',{'perpendicular','parallel'}));

if ~isinf(Parameters.Temperature)
  warning('Boltzmann equilibrium not implemented. Parameters.Temperature is ignored!');
end

mwFreq = Parameters.mwFreq*1e3;
Orientation = Parameters.Orientations;

% Process orientation array.
%===================================================================
[nAngles,nOrientations] = size(Orientation);
switch nAngles
case 2,
  Orientation(3,end) = 0;
  IntegrateOverChi = 1;
case 3,
  IntegrateOverChi = 0;
otherwise
  error(sprintf('Orientations array has %d rows instead of 2 or 3.',nAngles));
end

% Process options structure.
%===================================================================
DefaultOptions.Freq2Field = 1;
DefaultOptions.Threshold = 0;
DefaultOptions.RejectionRatio = 1e-8; % UNDOCUMENTED!

Options = adddefaults(Options,DefaultOptions);

if (Options.Freq2Field~=1)&(Options.Freq2Field~=0)
  error('Options.Freq2Field incorrect!');
end

ComputeFreq2Field = (1==Options.Freq2Field);
%ComputeFreq2Field = 1;

% Build Hamiltonian components.
%===================================================================
if iscell(SpinSystem)
  [F,Gx,Gy,Gz] = deal(SpinSystem);
else
  [F,Gx,Gy,Gz] = sham(SpinSystem);
end

% Build Liouville space operators.
A = eyekron(F) - kroneye(conj(F)) + mwFreq*eye(length(F)^2);

% Check if is positive-definite. If yes, a simple eigenvalue
% problem has to be solved, not the general one.
[V,E] = eig(A);
E = diag(E);
SimpleEigenproblem = all(E>0);
if SimpleEigenproblem,
  invA = V*diag(1./E)*V';
  msg = 'reduced to simple eigenproblem';
else
  msg = 'general eigenproblem';
end
logmsg(1,'  %s, matrix size %dX%d',msg,length(A),length(A));
clear V E;

% Prepare vectors for intensity computation.
if ComputeIntensities
  vGx = reshape(Gx.',numel(Gx),1);
  vGy = reshape(Gy.',numel(Gy),1);
  vGz = reshape(Gz.',numel(Gz),1);
end

% Loop over all orientations of the spin system.
EigenFields = cell(1,nOrientations);
Intensities = cell(1,nOrientations);

for iOri = 1:nOrientations
  logmsg(3,'  orientation %d of %d',iOri,nOrientations);
  
  Mol2LabRotation = erot(Orientation(:,iOri));
  % z laboratoy axis: external static field.
  zLab = Mol2LabRotation(3,:);
  GzL = zLab(1)*Gx + zLab(2)*Gy + zLab(3)*Gz;

  B = kroneye(conj(GzL)) - eyekron(GzL);
  if SimpleEigenproblem, BB = invA*B; end

  if ComputeIntensities
    % Eigenvectors correspond to reshape(|u><v|,[],1) = kron(conj(v),u)
    % For a given eigenfield, u and v are the states with Ev-Eu = mwFreq
    if SimpleEigenproblem
      [Vecs,Fields] = eig(BB);
      [Fields,idx] = sort(1./diag(Fields));
      Vecs = Vecs(:,idx);
    else
      [Vecs,Fields] = eig(A,B);
      [Fields,idx] = sort(diag(Fields));
      Vecs = Vecs(:,idx);
    end

    % Remove negative, nonfinite and complex eigenfields
    % and those above user limit Options.MaxField
    idx = (abs(imag(Fields))<Options.RejectionRatio*abs(real(Fields))) & ...
      (Fields>0) & isfinite(Fields) & ...
      (Fields>Parameters.Range(1)) & (Fields<Parameters.Range(2));
    if ~any(idx)
      EigenFields{iOri} = [];
      Intensities{iOri} = [];
    else
      EigenFields{iOri} = real(Fields(idx));
      Vecs = Vecs(:,idx);
      
      % Normalize eigenvectors to unity
      Norms = sqrt(sum(abs(Vecs).^2));
      Vecs = Vecs./Norms(ones(size(Vecs,1),1),:);
      
      % Compute Zeeman operators along x and y
      idx = ones(1,length(EigenFields{iOri}));
      if (ParallelMode)
        vGzL = zLab(1)*vGx + zLab(2)*vGy + zLab(3)*vGz;
        TransProp = abs(sum(vGzL(:,idx).*Vecs)).^2;
      else
        xLab = Mol2LabRotation(1,:);
        vGxL = xLab(1)*vGx + xLab(2)*vGy + xLab(3)*vGz;
        if (IntegrateOverChi)
          yLab = Mol2LabRotation(2,:);
          vGyL = yLab(1)*vGx + yLab(2)*vGy + yLab(3)*vGz;
          % Calculate transition rate using <v|A|u> = trace(A|u><v|)
          TransProp = pi * (abs(sum(vGxL(:,idx).*Vecs)).^2 + abs(sum(vGyL(:,idx).*Vecs)).^2);
        else
          TransProp = abs(sum(vGxL(:,idx).*Vecs)).^2;
        end
      end
      
      % Compute frequency-to-field domain conversion factor
      if ComputeFreq2Field
        % 1/(<v|G|v>-<u|G|u>) = 1/(trace(G|v><v|) - trace(G|u><u|)) =
        %   1/trace(A*(|v><v|-|u><u|)) = 1/trace(A*commute(|u><v|,|v><u|))
        % |u><u| = (|u><v|)(|v><u|)
        n = length(F);
        Vecs = reshape(Vecs,n,n,numel(Vecs)/n^2);
        Freq2Field = [];
        for iVec = 1:size(Vecs,3)
          V = Vecs(:,:,iVec);
          Freq2Field(iVec) = 1/abs(trace(GzL*commute(V,V')));
        end
      else
        Freq2Field = ones(size(TransProp));
      end
      
      Intensities{iOri} = real(TransProp.*Freq2Field).';
      
      idx = Intensities{iOri}>=Options.Threshold(1)*max(Intensities{iOri});
      EigenFields{iOri} = EigenFields{iOri}(idx);
      Intensities{iOri} = Intensities{iOri}(idx);
    end
  else
    
    if (SimpleEigenproblem)
      Fields = eig(BB);
      Fields = sort(1./Fields);
    else
      Fields = eig(A,B);
      Fields = sort(Fields);
    end

    inRange = (abs(imag(Fields))<Options.RejectionRatio*abs(real(Fields))) & ...
      (Fields>0) & isfinite(Fields) & ...
      (Fields>Parameters.Range(1)) & (Fields<Parameters.Range(2));
    EigenFields{iOri} = real(Fields(inRange));
    Intensities = {[]};
    
  end
  
end

% One orientation: simple array instead of 1x1 cell array as output!
if (nOrientations==1),
  EigenFields = EigenFields{1};
  Intensities = Intensities{1};
end

% Prepare output.
varargout = {EigenFields,Intensities};
varargout = varargout(1:max(nargout,1));

% Restore original warning state.
warning(OldWarningState);

return
%=======================================================================
%=======================================================================


%=======================================================================
% supplementary functions
%=======================================================================
function B = eyekron(A,n)
% A version of kron(eye(n),A) without multiplications. Esp. for big
% matrices this gives a significant performance boost.
% Equivalent to kron(eye(length(A)),A) or kron(eye(n),A).
if nargin==1, n = length(A); end
[r,c] = size(A);
B = zeros(r*n,c*n);
Rows = 1:r; Cols = 1:c;
for k = 1:n
  B(Rows,Cols) = A;
  Rows = Rows + r; Cols = Cols + c;
end
return


function B = kroneye(A,n)
% A version of kron(A,eye(n)) without multiplications. Esp. for big
% matrices this gives a significant performance boost.
% Equivalent to kron(A,eye(length(A))) or kron(A,eye(n)).
if nargin==1, n = length(A); end
[r,c] = size(A);
B = zeros(r*n,c*n);
Rows = 0:n:(r-1)*n; Cols = 0:n:(c-1)*n;
for k = 1:n
  Rows = Rows + 1; Cols = Cols + 1;
  B(Rows,Cols) = A;
end
return
