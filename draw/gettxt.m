function [   meannum ] = gettxt(fn)
%��ȡtxt�е�����
times=30;
hangshu=101;
fp1 =fopen (fn, 'rt');   
  count=1;
  while count~=hangshu*30+1%���ö�ȡ����������+1
      str=strsplit( fgetl(fp1))  ;%���зָ�

            num(count)=str2num(str{2})  ;%ȡ����������
  
       count=count+1;
  end
  meannum=[];

  for line=1:101
       num2=[];
     for i=1:times                                   
          num2=[num2 num(line+hangshu*(i-1)) ];
     end
     meannum(line)=mean(num2);
  end
   fclose(fp1);
end

