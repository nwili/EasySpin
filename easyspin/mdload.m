%  mdload  Load data generated by molecular dynamics simulations.
%
%   MD = mdload(TrajFile, AtomInfo);
%   MD = mdload(TrajFile, AtomInfo, OutOpt);
%
%   Input:
%     TrajFile       character array
%                    Name of trajectory output file.
%
%     AtomInfo       structure array containing the following fields
%
%                    TopFile    character array
%                               Name of topology input file used for 
%                               molecular dynamics simulations.
%
%                    SegName    character array
%                               Name of segment in the topology file
%                               assigned to the spin-labeled protein.
%
%                    ResName    character array
%                               Name of residue assigned to spin label side 
%                               chain, e.g. "CYR1" is the default used by 
%                               CHARMM-GUI.
%
%                    AtomNames  structure array
%                               Contains the atom names used in the PSF to 
%                               refer to the following atoms in the 
%                               nitroxide spin label molecule model:
%
%                                    ON (ONname)
%                                    |
%                                    NN (NNname)
%                                  /   \
%                        (C1name) C1    C2 (C2name)
%                                 |     |
%                       (C1Rname) C1R = C2R (C2Rname)
%                                 |
%                       (C1Lname) C1L
%                                 |
%                       (S1Lname) S1L
%                                /
%                      (SGname) SG
%                               |
%                      (CBname) CB
%                               |
%                   (Nname) N - CA (CAname)
%
%     OutOpt         structure array containing the following fields
%
%                    Verbosity 0: no display, 1: (default) show info
%
%
%   Output:
%     MD             structure array containing the following fields:
%
%                    nSteps    integer
%                              total number of steps in trajectory
%
%                    dt        double
%                              size of time step (in s)
%
%                    ProtCAxyz numeric array, size = (nSteps,nResidues,3)
%                              xyz coordinates of protein alpha carbon
%                              atoms
%
%                    FrameX    numeric array, size = (nSteps,3)
%                              xyz coordinates of coordinate frame x-axis
%                              vector
%
%                    FrameY    numeric array, size = (nSteps,3)
%                              xyz coordinates of coordinate frame y-axis
%                              vector
%
%                    FrameZ    numeric array, size = (nSteps,3)
%                              xyz coordinates of coordinate frame z-axis
%                              vector
%
%                    chi1-chi5 numeric array, size = (nSteps,5)
%                              dihedral angles of spin label side chain
%                              bonds
%
%

%
%
%   Supported formats are identified via the extension
%   in 'TrajFile' and 'TopFile'. Extensions:
%
%     NAMD, CHARMM:        .DCD, .PSF
%

function MD = mdload(TrajFile, AtomInfo, OutOpt)

switch nargin
  case 0
    help(mfilename); return;
  case 2 % TrajFile and AtomInfo specified, initialize Opt
    OutOpt = struct;
  case 3 % TrajFile, AtomInfo, and Opt provided
  otherwise
    error('Incorrect number of input arguments.')
end

% if ~isfield(OutOpt,'Type'), OutOpt.Type = 'Protein+Frame'; end
if ~isfield(OutOpt,'Verbosity'), OutOpt.Verbosity = 1; end

% OutType = OutOpt.Type;

% supported file types
supportedTrajFileExts = {'.DCD'};
supportedTopFileExts = {'.PSF'};

if isfield(AtomInfo,'TopFile')
  TopFile = AtomInfo.TopFile;
else
  error('AtomInfo.TopFile is missing.')
end

if isfield(AtomInfo,'ResName')
  ResName = AtomInfo.ResName;
else
  error('AtomInfo.ResName is missing.')
end

if isfield(AtomInfo,'AtomNames')
  AtomNames = AtomInfo.AtomNames;
else
  error('AtomInfo.AtomNames is missing.')
end

if isfield(AtomInfo,'SegName')
  SegName = AtomInfo.SegName;
else
  error('AtomInfo.SegName is missing.')
end

if ~ischar(TopFile)||regexp(TopFile,'\w+\.\w+','once')<1
  error('TopFile must be given as a character array, including the filename extension.')
end

% if numel(regexp(TopFile,'\.'))>1
%   error('Only one period (".") can be included in TopFile as part of the filename extension. Remove the others.')
% end

if exist(TopFile,'file')>0
  [TopFilePath, TopFileName, TopFileExt] = fileparts(TopFile);
  TopFile = fullfile(TopFilePath, [TopFileName, TopFileExt]);
else
  error('TopFile "%s" could not be found.', TopFile)
end

if ischar(TrajFile)
  % single trajectory file
  
  if exist(TrajFile,'file')>0
    % extract file extension and file path
    [TrajFilePath, TrajFileName, TrajFileExt] = fileparts(TrajFile);
    % add full file path to TrajFile
    TrajFile = fullfile(TrajFilePath, [TrajFileName, TrajFileExt]);
  else
    error('TrajFile "%s" could not be found.', TrajFile)
  end
  
  TrajFile = {TrajFile};
  TrajFilePath = {TrajFilePath};
  TrajFileExt = {TrajFileExt};
  nTrajFiles = 1;
elseif iscell(TrajFile)
  % multiple trajectory files
  if ~all(cellfun('isclass', TrajFile, 'char'))
    error('If TrajFile is a cell array, each element must be a character array.')
  end
  nTrajFiles = numel(TrajFile);
  TrajFilePath = cell(nTrajFiles,1);
  TrajFileName = cell(nTrajFiles,1);
  TrajFileExt = cell(nTrajFiles,1);
  for k=1:nTrajFiles
    if exist(TrajFile{k},'File')>0
      [TrajFilePath{k}, TrajFileName{k}, TrajFileExt{k}] = fileparts(TrajFile{k});
      TrajFile{k} = fullfile(TrajFilePath{k}, [TrajFileName{k}, TrajFileExt{k}]);
    else
      error('TrajFile "%s" could not be found.', TrajFile{k})
    end
  end
  % make sure that all file extensions are identical
  if ~all(strcmp(TrajFileExt,TrajFileExt{1}))
    error('At least two of the TrajFile file extensions are not identical.')
  end
  if ~all(strcmp(TrajFilePath,TrajFilePath{1}))
    error('At least two of the TrajFilePath locations are not identical.')
  end
else
  error(['Please provide ''TrajFile'' as a single character array ',...
         '(single trajectory file) or a cell array whose elements are ',...
         'character arrays (multiple trajectory files).'])
end

TrajFileExt = upper(TrajFileExt{1});
TopFileExt = upper(TopFileExt);

% check if file extensions are supported

if ~any(strcmp(TrajFileExt,supportedTrajFileExts))
  error('The TrajFile extension "%s" is not supported.', TrajFileExt)
end

if ~any(strcmp(TopFileExt,supportedTopFileExts))
  error('The TopFile extension "%s" is not supported.', TopFileExt)
end

ExtCombo = [TrajFileExt, ',', TopFileExt];

if OutOpt.Verbosity==1, tic; end

% parse through list of trajectory output files
for iTrajFile=1:nTrajFiles
  [temp,psf] = processMD(TrajFile{iTrajFile}, TopFile, SegName, ResName, AtomNames, ExtCombo);
  if iTrajFile==1
    MD = temp;
  else
    % combine trajectories through array concatenation
    if MD.dt~=temp.dt
      error('Time steps of trajectory files %s and %s are not equal.',TrajFile{iTrajFile},TrajFile{iTrajFile-1})
    end
    MD.nSteps = MD.nSteps + temp.nSteps;
    MD.ProtCAxyz = cat(1, MD.ProtCAxyz, temp.ProtCAxyz);
    MD.Labelxyz = cat(1, MD.Labelxyz, temp.Labelxyz);
  end
  % this could take a long time, so notify the user of progress
  if OutOpt.Verbosity
    updateuser(iTrajFile,nTrajFiles)
  end
end

ONxyz = MD.Labelxyz(:,:,psf.idx_ON);
NNxyz = MD.Labelxyz(:,:,psf.idx_NN);
C1xyz = MD.Labelxyz(:,:,psf.idx_C1);
C2xyz = MD.Labelxyz(:,:,psf.idx_C2);
C1Rxyz = MD.Labelxyz(:,:,psf.idx_C1R);
C2Rxyz = MD.Labelxyz(:,:,psf.idx_C2R);
C1Lxyz = MD.Labelxyz(:,:,psf.idx_C1L);
S1Lxyz = MD.Labelxyz(:,:,psf.idx_S1L);
SGxyz = MD.Labelxyz(:,:,psf.idx_SG);
CBxyz = MD.Labelxyz(:,:,psf.idx_CB);
CAxyz = MD.Labelxyz(:,:,psf.idx_CA);
Nxyz = MD.Labelxyz(:,:,psf.idx_N);

% ONxyz = cat(1, MD.ONxyz, temp.ONxyz);
% NNxyz = cat(1, MD.NNxyz, temp.NNxyz);
% C1xyz = cat(1, MD.C1xyz, temp.C1xyz);
% C2xyz = cat(1, MD.C2xyz, temp.C2xyz);
% C1Rxyz = cat(1, MD.C1Rxyz, temp.C1Rxyz);
% C2Rxyz = cat(1, MD.C2Rxyz, temp.C2Rxyz);
% C1Lxyz = cat(1, MD.C1Lxyz, temp.C1Lxyz);
% S1Lxyz = cat(1, MD.S1Lxyz, temp.S1Lxyz);
% SGxyz = cat(1, MD.SGxyz, temp.SGxyz);
% CBxyz = cat(1, MD.CBxyz, temp.CBxyz);
% CAxyz = cat(1, MD.CAxyz, temp.CAxyz);
% Nxyz = cat(1, MD.Nxyz, temp.Nxyz);

% Calculate frame vectors

% N-O bond vector
NO_vec = ONxyz - NNxyz;

% N-C1 bond vector
NC1_vec = C1xyz - NNxyz;

% N-C2 bond vector
NC2_vec = C2xyz - NNxyz;

% Normalize vectors
NO_vec = NO_vec./sqrt(sum(NO_vec.*NO_vec,2));
NC1_vec = NC1_vec./sqrt(sum(NC1_vec.*NC1_vec,2));
NC2_vec = NC2_vec./sqrt(sum(NC2_vec.*NC2_vec,2));

vec1 = cross(NC1_vec, NO_vec, 2);
vec2 = cross(NO_vec, NC2_vec, 2);

MD.FrameZ = (vec1 + vec2)/2;
MD.FrameZ = MD.FrameZ./sqrt(sum(MD.FrameZ.*MD.FrameZ,2));
MD.FrameX = NO_vec;
MD.FrameY = cross(MD.FrameZ, MD.FrameX, 2);

% Calculate side chain dihedral angles
MD.chi1 = dihedral(Nxyz,CAxyz,CBxyz,SGxyz);
MD.chi2 = dihedral(CAxyz,CBxyz,SGxyz,S1Lxyz);
MD.chi3 = dihedral(CBxyz,SGxyz,S1Lxyz,C1Lxyz);
MD.chi4 = dihedral(SGxyz,S1Lxyz,C1Lxyz,C1Rxyz);
MD.chi5 = dihedral(S1Lxyz,C1Lxyz,C1Rxyz,C2Rxyz);

% % Remove individual atom xyz coordinates
% AtomFieldCell = {'ONxyz','NNxyz','C1xyz','C2xyz','C1Rxyz',...
%                  'C2Rxyz','C1Lxyz','S1Lxyz','SGxyz','CBxyz','CAxyz',...
%                  'Nxyz'};
% MD = rmfield(MD, AtomFieldCell);

end

function [Traj,psf] = processMD(TrajFile, TopFile, SegName, ResName, AtomNames, ExtCombo, OutType)
% 

switch ExtCombo
  case '.DCD,.PSF'
    % obtain atom indices of nitroxide coordinate atoms
    psf = md_readpsf(TopFile, SegName, ResName, AtomNames);  % TODO perform consistency checks between topology and trajectory files
    
    Traj = md_readdcd(TrajFile, psf.idx_ProteinLabel);

    % protein alpha carbon atoms
    Traj.ProtCAxyz = Traj.xyz(:,:,psf.idx_ProteinCA);

    % spin label atoms
    Traj.Labelxyz = Traj.xyz(:,:,psf.idx_SpinLabel);
%     Traj.ONxyz = Traj.xyz(:,:,psf.idx_ON==psf.idx_SpinLabel);
%     Traj.NNxyz = Traj.xyz(:,:,psf.idx_NN==psf.idx_SpinLabel);
%     Traj.C1xyz = Traj.xyz(:,:,psf.idx_C1==psf.idx_SpinLabel);
%     Traj.C2xyz = Traj.xyz(:,:,psf.idx_C2==psf.idx_SpinLabel);
%     Traj.C1Rxyz = Traj.xyz(:,:,psf.idx_C1R==psf.idx_SpinLabel);
%     Traj.C2Rxyz = Traj.xyz(:,:,psf.idx_C2R==psf.idx_SpinLabel);
%     Traj.C1Lxyz = Traj.xyz(:,:,psf.idx_C1L==psf.idx_SpinLabel);
%     Traj.S1Lxyz = Traj.xyz(:,:,psf.idx_S1L==psf.idx_SpinLabel);
%     Traj.SGxyz = Traj.xyz(:,:,psf.idx_SG==psf.idx_SpinLabel);
%     Traj.CBxyz = Traj.xyz(:,:,psf.idx_CB==psf.idx_SpinLabel);
%     Traj.CAxyz = Traj.xyz(:,:,psf.idx_CA==psf.idx_SpinLabel);
%     Traj.Nxyz = Traj.xyz(:,:,psf.idx_N==psf.idx_SpinLabel);
    
    % remove the rest
    Traj = rmfield(Traj, 'xyz');
  otherwise
    error('TrajFile type "%s" and TopFile "%s" type combination is either ',...
          'not supported or not properly entered. Please see documentation.', TrajFileExt, TopFileExt)
end

end

function updateuser(iter,totN)
% Update user on progress

persistent reverseStr

if isempty(reverseStr), reverseStr = ''; end

avg_time = toc/iter;
secs_left = (totN - iter)*avg_time;
mins_left = floor(secs_left/60);

msg1 = sprintf('Iteration: %d/%d\n', iter, totN);
if avg_time<1.0
  msg2 = sprintf('%2.1f it/s\n', 1/avg_time);
else
  msg2 = sprintf('%2.1f s/it\n', avg_time);
end
msg3 = sprintf('Time left: %d:%2.0f\n', mins_left, mod(secs_left,60));
msg = [msg1, msg2, msg3];

fprintf([reverseStr, msg]);
reverseStr = repmat(sprintf('\b'), 1, length(msg));

end

function DihedralAngle = dihedral(a1Traj,a2Traj,a3Traj,a4Traj)
% function DihedralAngle = dihedral(traj,atomlist)
% calculate dihedral angle given 4 different atom indices and a trajectory
% idx_atom1 = atomlist{1};
% idx_atom2 = atomlist{2};
% idx_atom3 = atomlist{3};
% idx_atom4 = atomlist{4};

% a1 = traj(:, :, idx_atom1) - traj(:, :, idx_atom2);
a1 = a1Traj - a2Traj;
a1 = a1./sqrt(sum(a1.*a1, 2));
% a2 = traj(:, :, idx_atom3) - traj(:, :, idx_atom2);
a2 = a3Traj - a2Traj;
a2 = a2./sqrt(sum(a2.*a2, 2));
% a3 = traj(:, :, idx_atom3) - traj(:, :, idx_atom4);
a3 = a3Traj - a4Traj;
a3 = a3./sqrt(sum(a3.*a3, 2));

b1 = cross(a2, a3, 2);
b2 = cross(a1, a2, 2);

vec1 = dot(a1, b1, 2);
vec1 = vec1.*sum(a2.*a2, 2).^0.5;
vec2 = dot(b1, b2, 2);

DihedralAngle = atan2(vec1, vec2);

end

%                    Format    'Protein+Frame': (default) xyz coordinates 
%                                of alpha carbon atoms in the protein and 
%                                coordinate frame vector trajectories given
%                                as output
%                              'Frame': coordinate frame vector 
%                                trajectories given as output
%                              'Dihedrals': spin label side chain dihedrals 
%                                given as output

%     switch OutType
%       case 'Protein+Frame'
%       case 'Frame'
%       case 'Dihedrals'

% function status = FileExist(FileName)
% 
% 
% 
% end