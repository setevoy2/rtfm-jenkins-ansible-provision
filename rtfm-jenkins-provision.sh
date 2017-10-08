#!/usr/bin/env bash

RSA_LOCAL_PATH="/home/setevoy/Work/RTFM/Bitbucket/aws-credentials/rtfm-jenkins.pem"

JENKINS_STACK_WORKDIR="/home/setevoy/Work/RTFM/Github/rtfm-blog-cf-templates"
JENKINS_STACK_TEMPLATE="rtfm_jenkins_stack.json"

JENKINS_ANSIBLE_WORKDIR="/home/setevoy/Work/RTFM/Github/rtfm-jenkins-ansible-provision/"
JENKINS_ANSIBLE_PLAYBOOK="jenkins-provision.yml"

JENKINS_EBS_ID="vol-0085149b3a0a45d0c"

HELP="\n\tCreate and provision Jenkins stack script.\n\n\t-b: backup Jenkins EBS to S3\n\t-c: run Stack create (use -s for Stack name!)\n\t-u: run Stack updatei (use -s for Stack name!)\n\t-a: run Ansible playbook\n\t-i: Allowed IP\n\t-s: Stack name\n\t-h: print this Help\n"

backup_ebs=
create_stack=
update_stack=
run_ansible=
allow_ip=
stack_name=

while getopts "bcuai:s:h" opt; do
	case $opt in
        b)  
            backup_ebs=1
            echo "Creating stack"
            ;; 
		c) 
			create_stack=1
			echo "Creating stack"
			;;
		u)
			update_stack=1
			echo "Update stack"
			;;
		a)
			run_ansible=1
			echo "Run Ansible"
			;;
        i)
            allow_ip=$OPTARG
			echo "Allowed IP $allow_ip"
            ;;
        s)
            stack_name=$OPTARG
			echo "Stack name $stack_name"
            ;;
		h) echo -e "$HELP"
			;;
	esac
done

create_ebs_backup () {

	now=$(date +"%y-%m-%d-%H-%M")
	aws ec2 create-snapshot --volume-id $JENKINS_EBS_ID --description "$now Jenkins EBS backup"
}

create_aws_stack () {
		
	aws cloudformation create-stack --stack-name $stack_name --template-body file://$JENKINS_STACK_WORKDIR/$JENKINS_STACK_TEMPLATE --parameters ParameterKey=HomeAllowLocation,ParameterValue=$allow_ip/32
}

update_aws_stack () {

	aws cloudformation update-stack --stack-name $stack_name --template-body file://$JENKINS_STACK_WORKDIR/$JENKINS_STACK_TEMPLATE --parameters ParameterKey=HomeAllowLocation,ParameterValue=$allow_ip/32
}

ansible_run_playbook () {

	cd $JENKINS_ANSIBLE_WORKDIR || exit 1
	ansible-galaxy install --role-file requirements.yml || exit 1
	ansible-playbook --syntax-check $JENKINS_ANSIBLE_PLAYBOOK || exit 1
	ansible-playbook $JENKINS_ANSIBLE_PLAYBOOK --private-key=$RSA_LOCAL_PATH
}


if [[ $backup_ebs == 1 ]]; then
	echo -e "\nRunning Jenkins EBS backup...\n"
	create_ebs_backup && echo -e "\nDone.\n" || { echo -e "ERROR: can't finish backup. Exit.\n"; exit 1; }
fi

if [[ $create_stack == 1 ]] && [[ $stack_name ]] && [[ $allow_ip ]]; then
    echo -e "\nCreating Jenkins CloudFormation stack $stack_name with AllowedIP $allow_ip...\n"
    create_aws_stack && echo -e "\nDone.\n" || { echo -e "ERROR: can't execute create-stack. Exit.\n"; exit 1; }
fi

if [[ $update_stack == 1 ]] && [[ $stack_name ]] && [[ $allow_ip ]]; then
    echo -e "\nUpdating Jenkins CloudFormation stack $stack_name with AllowedIP $allow_ip...\n"
    update_aws_stack && echo -e "\nDone.\n" || { echo -e "ERROR: can't execute create-stack. Exit.\n"; exit 1; }
fi

if [[ $run_ansible == 1 ]]; then
    echo -e "\nRunning Jenkins Ansible playbook...\n"
   ansible_run_playbook && echo -e "\nDone.\n" || { echo -e "ERROR: can't finish backup. Exit.\n"; exit 1; }
fi

