function simpat = genEBSDPatternHybrid(g,params,F,lattice,alattice,blattice,clattice,axs)
%Name: genEBSDPattern.m
%Date: 1/01/2008
%By:   Colin Landon
%Desc: The first argument is an orienation (either 3x3 matrix or vector of
%       three Euler angles [phi1,PHI,phi2]
%       The second argument is a cell array of parameters
%       {xstar,ystar,zstar,pixsize(the size of one side of the phospher
%       screen in pixels), Av (the accelerating voltage),sampletilt (in
%       radians)(typically 70 degrees),elevang (the elevation angle in
%       radians), Fhkl (the structure factor), dhkl (the interplaner
%       spacing, and hkl (the crysal plane normal)}
%      This code generates bands with intensity based on the structure
%      factor squared. Now works for hexagonal as well as cubic

% This code works as of Jan 1,2008 tested on g=[0 0 0] and g=[35 70 200]

xstar = params{1};
ystar = params{2};
zstar = params{3};
pixsize = params{4};
Av = params{5};
sampletilt = params{6};
elevang = params{7};
Fhkl = params{8};
dhkl = params{9};
hkl = params{10};
sFhkl = Fhkl.^2;
% sFhkl = Fhkl;
%calculate wavelength
Wa = 6.626e-34/sqrt(2*1.602e-19*9.109e-31*Av+(1.602e-19*Av/2.998e8)^2);
%calculate cone angle

alpha = pi/2 - sampletilt + elevang;
simpat = zeros(pixsize,pixsize);
% SinglePattern = zeros(pixsize,pixsize);
% OnesMat = ones(pixsize,pixsize);
% keyboard
%Coordinate frame transformation
Qvp=[-1 0 0; 0 -1 0; 0 0 1];
Dvp=[(xstar)*pixsize;(1-ystar)*pixsize;0]; % pattern center in phosphor frame
% Sample to Crystal
if length(g(:)) < 9
    phi1=g(1);
    PHI=g(2);
    phi2=g(3);
    Qsc=euler2gmat(phi1,PHI,phi2); %rotation sample to crystal
else
    Qsc=g;
end
[R U] = poldec(Qsc);
if sum(sum(U-eye(3)))>1e-10
    error('g must be a pure rotation')
end
% [R F]=poldec(F);
% Qsc=Qsc*R';
Qcs=Qsc';

% Phospher to sample
Qps=[0 -cos(alpha) -sin(alpha);...
    -1     0            0;...
    0   sin(alpha) -cos(alpha)];
Qsp=Qps';
% Qpc=Qsc*Qps;
% Translation between frames
% Dps=Qps*[0;0;-zstar*pixsize];%in pixels in sample frame
Dsp=[0;0;zstar*pixsize];% position of sample described in phosphor frame
% x=1:1000;
% y=1:1000;
% [Xv Yv]=meshgrid(x,y);
% %phospher described in phospher frame
%  xp=Qvp(1,1)*Xv+Qvp(1,2)*Yv+Dvp(1);
%  yp=Qvp(2,1)*Xv+Qvp(2,2)*Yv+Dvp(2);
%  zp=Qvp(3,1)*Xv+Qvp(3,2)*Yv+Dvp(3);

UsePermHKL = 0; %can't get this working for anything non-cubic, so use old 
%method for other symmetries. PermuteHKL does speed up cubic symmetries
%significantly and removes double counting. Some day someone should get it
%working for other symmetries as well and then use genEBSDVect.m
if strcmp(lattice,'hexagonal') == 1
    SymOps = gensymopsHex;
    numsyms = 12;
elseif strcmp(lattice,'tetragonal')
    SymOps = gensymopsTet(axs);
    numsyms = 8;
elseif strcmp(lattice,'cubic')
    UsePermHKL = 1;
end

for i = 1:length(dhkl)
    
    if UsePermHKL
        NewHKLList = PermuteHKL(hkl(i,:),lattice);
%         for j = 1:size(NewHKLList,1)%numsyms
            numsyms = size(NewHKLList,1);
    end
    for j = 1:numsyms
        if UsePermHKL
                  eco3 = NewHKLList(j,:)';
        else
            eco3=hkl(i,:);
        end
        if eco3(1) ~= 0
            eco3(1) = 1/eco3(1);
            eco3(1) = eco3(1)*alattice;
            %             eco3(1) = eco3(1)*1/alattice;
            eco3(1) = 1/eco3(1);
        end
        if eco3(2) ~= 0
            eco3(2)= 1/eco3(2);
            eco3(2) = eco3(2)*blattice;
            %             eco3(2) = eco3(2)*1/blattice;
            eco3(2)= 1/eco3(2);
        end
        if eco3(3) ~= 0
            eco3(3) = 1/eco3(3);
            eco3(3) = eco3(3)*alattice; % ****this was clattice but is now alattice due to changes in hkl values for HCP, may need to fix for tetragonal
            %             eco3(3) = eco3(3)*1/clattice;
            eco3(3) = 1/eco3(3);
        end
        if ~UsePermHKL
            eco3 = squeeze(SymOps(j,1:3,1:3))*eco3';
        end
        %         N=eco3/norm(eco3);
     
        C=eco3/norm(eco3)*dhkl(i);% normal to hkl plane, with length equal to distance between planes
        if C(3) == 0%my stuff
            A = [0 0 1]';% normal vector to C
        else%my stuff
            A = [1 1 -(C(1)+C(2))/C(3)]';% normal vector to C
        end%my stuff
 
        B = cross2(A,C);% normal vector to A and C
        NPreNorm = cross2(A,B);% this should be in direction of C (normal to hkl plane) - can't remember why all the work with A and B
        N = NPreNorm/norm(NPreNorm);
        n = norm(NPreNorm)/norm(cross2(F*A,F*B))*det(F)*inv(F)'*N;% deformed normal to hkl plane in crystal frame
        tdhkl = abs(xdotyMex((F*C)',n));% deformed distance between planes????
        theta=asin(Wa/2/tdhkl);
        %         eco3=Qcs*n';
        eco3 = Qcs*n; % normal to hkl plane in sample frame; ecoi are the axes of the reference frame associated with the cone for this hkl frame
        %Find the in plane bases in the crystal frame
        %         eco3=F*eco3;
        %         eco3=Qcs*eco3;
        eco3=eco3';
        eco3=eco3/norm(eco3);
        eco2=[0 0 0];
        if eco3(1)==0;
            eco2(1)=1;
        elseif eco3(2)==0
            eco2(2)=1;
        elseif eco3(3)==0
            eco2(3)=1;
        else
            eco2(1)=1;
            eco2(2)=1;
            eco2(3)=(-eco3(1)-eco3(2))/eco3(3);
            eco2=eco2/norm(eco2);
        end
        eco1=cross(eco2,eco3);
        Qcos=[eco1' eco2' eco3'];
        Qsco=Qcos';
        Qpco=Qsco*Qps;
        Qcop=Qsp*Qcos;
        Qvco=Qpco*Qvp;
        Q=Qvco;
        Dpco=-Qpco*Dsp;
        Dcop=-Qcop*Dpco;
        Dcov=Qvp'*Dcop+-Qvp'*Dvp; % why +- *********?
        Dvco=-Qvco*Dcov;
        %Equation of intersection
        t=Dvco;
        ts=tan(theta)^2;
%         keyboard
        a=ts*(Q(1,1)^2+Q(2,1)^2)-Q(3,1)^2;%x^2
        b=ts*(Q(1,2)^2+Q(2,2)^2)-Q(3,2)^2;%y^2
        c=ts*(2*Q(1,1)*Q(1,2)+2*Q(2,1)*Q(2,2))-2*Q(3,1)*Q(3,2);%xy
        d=ts*(2*Q(1,1)*t(1)+2*Q(2,1)*t(2))-2*Q(3,1)*t(3);%x
        e=ts*(2*Q(1,2)*t(1)+2*Q(2,2)*t(2))-2*Q(3,2)*t(3);%y
        f=ts*(t(1)^2+t(2)^2)-t(3)^2;%1
        %Choose y and solve for
        y=0:pixsize-1;
        qa=a*ones(size(y));
        qb=(c*y+d*ones(size(y)));
        qc=(b*y.^2+e*y+f*ones(size(y)));
        
        xp=((-qb+sqrt(qb.^2-4*qa.*qc))./qa*.5);
        xm=((-qb-sqrt(qb.^2-4*qa.*qc))./qa*.5);
        
        %If necessary choose x and solve for y
        if sum(abs(imag(xp)))>0
            x=0:pixsize-1;
            qa=b*ones(size(x));
            qb=(c*x+e*ones(size(x)));
            qc=(a*x.^2+d*x+f*ones(size(x)));
            
            yp=((-qb+sqrt(qb.^2-4*qa.*qc))./qa*.5);
            ym=((-qb-sqrt(qb.^2-4*qa.*qc))./qa*.5);
            
            %sort to find the high and low vals
            ymin=ceil(min([yp;ym]));
            ymax=floor(max([yp;ym]));
%             ymin=round(min([yp;ym]));
%             ymax=round(max([yp;ym]));
            %max sure they fall on the screen
            x(ymin>pixsize)=[];
            ymax(ymin>pixsize)=[];
            ymin(ymin>pixsize)=[];
            x(ymax<1)=[];
            ymin(ymax<1)=[];
            ymax(ymax<1)=[];
            ymin(ymin<1)=1;
            ymax(ymax>pixsize)=pixsize;
            for ind=1:length(x)
                simpat((ymin(ind)):(ymax(ind)),x(ind)+1)=simpat((ymin(ind)):(ymax(ind)),x(ind)+1)+sFhkl(i);
            end
        else
            %sort to find the high and low vals
            xmin=ceil(min([xp;xm]));
%             xmin=round(min([xp;xm]));
            xmax=floor(max([xp;xm]));
%             xmax=round(max([xp;xm]));
            %make sure they fall on the screen
            y(xmin>pixsize)=[];
            xmax(xmin>pixsize)=[];
            xmin(xmin>pixsize)=[];
            y(xmax<1)=[];
            xmin(xmax<1)=[];
            xmax(xmax<1)=[];
            xmin(xmin<1)=1;
            xmax(xmax>pixsize)=pixsize;
            for ind=1:length(y)
                % applies a guassian distribution to the main bands
                
                %                 if i < 4
                %
                %                     le = xmax(ind)-xmin(ind)+1;
                %                     sincer = 1:le;
                %                     sincer = sincer-length(sincer)*.5;
                %                     sincer = exp(-sincer.^2/(2*(le*.5)^2));
                %                     simpat(y(ind)+1,(xmin(ind)):(xmax(ind))) = simpat(y(ind)+1,(xmin(ind)):(xmax(ind)))+sFhkl(i)*sincer;
                %
                %                 else
                %                     if ind == 1
                %                     xmin(ind)
                %                     xmax(ind)
                %                     keyboard
                %                     end
                simpat(y(ind)+1,(xmin(ind)):(xmax(ind))) = simpat(y(ind)+1,(xmin(ind)):(xmax(ind))) + sFhkl(i);
                
                %                 end
            end
            
        end
        
    end
    
end
simpatT=simpat;
% This is to help pick out points that are good in actual patterns
% bkgd=zeros(size(simpat));
% bkgd(1,1)=150;
% bkgd([1,1],[2,end])=-60;
% bkgd([2,end],[1,1])=-60;
% bkgd=real(ifft2(bkgd))*pixsize^2;
% bkgd=(bkgd-min(bkgd(:)))/(max(bkgd(:))-min(bkgd(:)));
% 
% simpat=single(simpatT*255/max(simpatT(:)).*bkgd);
% simpat=single(simpat*255/max(simpat(:)));
% keyboard
simpat=single(simpatT);
% keyboard
% for generating binary simulated patterns
% simpat(simpat == min(min(simpat))) = 0;
% simpat(simpat > min(min(simpat))) = 1;
% simpat=(simpat~=0);

