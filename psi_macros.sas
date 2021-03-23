*********************************************************************************;
* program name: psi_macros.sas ;
* project: hac and lvc ;
* description: macros from CMS PSI program to label diagnosis and poa codes - wide 
format. Used for psi_label.sas;
*********************************************************************************;
* number of diagnosis codes ; 
%let ndx = 25; 
%let npr = 25; 

/*Macro to compare all discharge diagnosis codes against format.*/
 %macro mdx(fmt);

 (%do i = 1 %to &ndx.-1;
  (put(DGNS_&i._CD,&fmt.) = '1') or
  %end;
  (put(DGNS_&ndx._CD,&fmt.) = '1'))

 %mend;

/*Macro to compare discharge secondary diagnosis codes against format.*/
 %macro mdx2(fmt);

 (%do i = 2 %to &ndx.-1;
  (put(DGNS_&i._CD,&fmt.) = '1') or
  %end;
  (put(DGNS_&ndx._CD,&fmt.) = '1'))

 %mend;

/*macro to compare discharge primary diagnosis code against format.*/
 %macro mdx1(fmt);

 (put(DGNS_1_CD,&fmt.) = '1')

 %mend;

/*macro to determine if measure format diagnosis is included in any secondary discharge 
diagnosis code as present on admission.*/
%macro mdx2q2(fmt);
1 = 1 then do;
  result = 0;
  do i = 2 to &ndx.;
    if put(diagnoses[i],&fmt.) = '1' then do;
      if poa[i] in ('Y','W') then
        result = 1;
    end;
  if result = 1 then leave;
  end;
end;
if result = 1
%mend;

/*macro to determine if measure format diagnosis is included in any secondary discharge 
diagnosis code as not present on admission.*/
%macro mdx2q1(fmt);
1 = 1 then do;
  result = 0;
  do i = 2 to &ndx.;
    if put(diagnoses[i],&fmt.) = '1' then
      if poa[i] in ('N','U',' ','E','1','X') then result = 1;
    if result = 1 then leave;
  end;
end;
if result = 1
%mend;

/*macro to compare all discharge procedure codes against format.*/
%macro mpr(fmt);
(%do i = 1 %to &npr.-1;
    (put(SRGCL_PRCDR_&i._CD,&fmt.) = '1') or
%end;
(put(SRGCL_PRCDR_&npr._CD,&fmt.) = '1'))
%mend;

/*Macro to count the number of procedures on the discharge that are operating room procedures.*/
%macro orcnt;
    orcnt = 0;
    %do i = 1 %to &npr.;
       if put(SRGCL_PRCDR_&i._CD,$ORPROC.) = '1' then orcnt + 1;
    %end;
%mend;

/*macro to compare discharge procedure codes against measure format and operating room 
format and count total.*/
 %macro mprcnt(fmt);
    mprcnt = 0;
    %do i = 1 %to &npr.;
       if put(SRGCL_PRCDR_&i._CD,&fmt.) = '1'    and
          put(SRGCL_PRCDR_&i._CD,$ORPROC.) = '1' then mprcnt + 1;
    %end;
 %mend;

/*macro to return first day an operating room procedure was conducted that was not the 
measure format based on prday.*/
%macro orday(fmt);
    orday = .;
    %do i = 1 %to &npr.;
       if put(SRGCL_PRCDR_&i._CD,$ORPROC.) = '1' and
          put(SRGCL_PRCDR_&i._CD,&fmt.)    = '0' then do;
          if SRGCL_PRCDR_PRFRM_&i._DT gt .z then do;
             if orday = . then orday = SRGCL_PRCDR_PRFRM_&i._DT;
             else if orday > SRGCL_PRCDR_PRFRM_&i._DT then orday = SRGCL_PRCDR_PRFRM_&i._DT;
          end;
       end;
    %end;
%mend;

/*Macro to return the first day a measure format procedure was conducted based on PRDAY.*/
 %macro mprday(fmt);
    mprday = .;
    %do i = 1 %to &npr.;
       if put(SRGCL_PRCDR_&i._CD,&fmt.) = '1' and SRGCL_PRCDR_PRFRM_&i._DT gt .z then do;
          if mprday le .z then mprday = SRGCL_PRCDR_PRFRM_&i._DT;
          else if mprday > SRGCL_PRCDR_PRFRM_&i._DT then mprday = SRGCL_PRCDR_PRFRM_&i._DT;
       end;
    %end;
 %mend;

/*Macro for PSI 11 to include in numerator if fmt procedure occurs after the first OR procedure
by DAYS */ 
 %macro psi11n(fmt,days);
    %mprday(&fmt.);
    if (orday ne . and mprday ne .) then do;
       if mprday >= orday + &days. then psi_11_num = 1;
    end;
    else do;
       if %mpr2(&fmt.) then psi_11_num = 1;
    end;
 %mend;

 /*Macro to compare secondary discharge procedure codes against format.*/
 %macro mpr2(fmt);
 (%do i = 2 %to &npr.-1;
  (put(SRGCL_PRCDR_&i._CD,&fmt.) = '1') or
  %end;
  (put(SRGCL_PRCDR_&npr._CD,&fmt.) = '1'))
 %mend;

/*Macro to determine if measure format diagnosis is included in any discharge diagnosis 
code as present on admission.*/
%macro mdxaq2(fmt);
1 = 1 then do;
  result = 0;
  do i = 1 to &ndx.;
    if put(diagnoses[i],&fmt.) = '1' then do;
      if poa[i] in ('Y','W') then result = 1;
    end;
  if result = 1 then leave;
  end;
end;
if result = 1
%mend;

