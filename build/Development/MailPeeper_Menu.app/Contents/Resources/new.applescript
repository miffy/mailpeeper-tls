

tell application "Address Book"
	activate
	set send_group to name of groups
	set end of send_group to "���ׂ�"
	set send_group to choose from list send_group with prompt "Group��I�����ĉ�����"
	
	--�L�����Z����������
	if send_group is false then
		return
	else if send_group is {"���ׂ�"} then
		--�S�Ă�I��
		set send_people to name of people
		set send_people to choose from list send_people with prompt "�N�ɑ���܂����H" with multiple selections allowed and empty selection allowed
		
		--�L�����Z����������
		if send_people is false then
			return
		end if
		
		--�O���[�v��I���i�����I�����Ȃ��j������H
		if send_people is {} then
			set send_people to name of people
		end if
		
		set email_list to {}
		repeat with this_person in send_people
			set end of email_list to value of email 1 of person (this_person as Unicode text)
		end repeat
		--set email_address to email_list as text
		
		--return email_list
	else
		--�O���[�v��I��
		set send_people to name of people of group (send_group as text)
		set send_people to choose from list send_people with prompt "�N�ɑ���܂����H" with multiple selections allowed and empty selection allowed
		
		--�L�����Z����������
		if send_people is false then
			return
		end if
		
		--�O���[�v��I���i�����I�����Ȃ��j������H
		if send_people is {} then
			set send_people to name of people of group (send_group as text)
		end if
		
		set email_list to {}
		repeat with this_person in send_people
			set end of email_list to value of email 1 of person (this_person as Unicode text)
		end repeat
		
		--set beginning of email_list to "mailto:"
		--set email_address to email_list as text
		--return email_list
	end if
end tell

set CurDelim to AppleScript's text item delimiters
set AppleScript's text item delimiters to ","
set email_address to email_list as text
set email_address to "mailto:" & email_address
open location email_address with error reporting
set AppleScript's text item delimiters to CurDelim