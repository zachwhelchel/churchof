class Ability
  include CanCan::Ability

  def initialize(user)
    
    user ||= User.new # guest user (not logged in)
    if user.has_role? :need_poster
        can :create, Need
        can :update, Need, Need.all do |need|
            need.need_stage.admin_incoming? && need.user_id_posted_by == user.id
        end
        can :read, Need, :user_id_posted_by => user.id
        can :read, Need, :is_public => true
        can :manage, Expense, :need => { :user_id_posted_by => user.id }
        can :read, Contribution, :need => { :user_id_posted_by => user.id }
        can :read, Resource
    end
    if user.has_role? :church_admin
        can :read, Need, :user_id_church_admin => user.id
        can :read, Need, :is_public => true
        can :update, Need, :user_id_church_admin => user.id
        can :set_is_public, Need, :user_id_church_admin => user.id
        can :set_in_progress_and_public, Need, :user_id_church_admin => user.id
        can :manage, Expense, :need => { :user_id_church_admin => user.id }
        can :manage, Update # this needs to be only for the appropriate ones
        can :read, Contribution, :need => { :user_id_church_admin => user.id }
        can :read, Resource
        can :read, ResourceFlag
        can :manage, ResourceFlag, :user_id_church_admin => user.id
    end
    if user.has_role? :need_leader
        can :read, Need, :user_id_need_leader => user.id
        can :read, Need, :is_public => true
        can :update, Need, :user_id_need_leader => user.id
        # can :set_is_public, Need, :user_id_church_admin => user.id
        can :manage, Expense, :need => { :user_id_need_leader => user.id }
        can :manage, Update # this needs to be only for the appropriate ones
        can :read, Contribution, :need => { :user_id_need_leader => user.id }
        can :read, Resource
    end
    if user.has_role? :super_admin
        can :update, User
        can :manage, Initiative
        can :manage, InitiativeMetric
        can :manage, Skill
        can :manage, Demographic
        can :manage, MatchContribution
        can :manage, MatchCampaign
    end
    if user.has_role? :validation_partner
        can :read, User
        can :add_user_as_full_rosm_member, User
        can :remove_user_as_full_rosm_member, User
    end
    if user.has_role? :pending_church_admin
        can :agree_to_church_admin_agreement, User
    end
    if user.has_role? :pending_need_poster
        can :agree_to_need_poster_agreement, User
    end
    if user.has_role? :pending_need_leader
        can :agree_to_need_leader_agreement, User
    end

    if user.has_role? :organization_resource_validation_partner
        can :manage, Organization
        can :add_user_as_resource_partner, User
        can :remove_user_as_resource_partner, User
        can :manage, OrganizationRole
        can :new, Skill
        can :create, Skill
        can :read, Resource
        can :read, MatchCampaign
        can :add_user_as_pending_need_poster, User
        can :add_user_as_pending_need_leader, User
        can :add_user_as_pending_church_admin, User
    end

    if user.has_role? :resource_partner
        can :manage, Resource, :user_id => user.id



        can :manage, ResourceEvent, :resource => { :user_id => user.id }
         
        can :read, Resource
        can :take_over_management, Resource do |resource|
            if resource.organization
                at_least_one = false
                resource.organization.organization_roles.each do |organization_role|
                    at_least_one = true if organization_role.user.id == user.id
                end
                at_least_one
            else
                false
            end
        end


        can :manage, Resource

    end
    can :read, Organization
    can :read, Resource, :public_status => :available_to_public
    can :read, OrganizationRole
    can :read, ResourceEvent, :resource => { :public_status => :available_to_public }


    can :read, Need do |need|
        at_least_one = false
        need.contributions.each do |contribution|
            at_least_one = true if contribution.user_id == user.id && contribution.succeded? && !contribution.reimbursed?
        end
        at_least_one
    end

    # This didnt work... will just lock it at the view level for now.
    # can :create, Contribution do |contribution|
    #     contribution.need.is_public
    # end

    can :create, Contribution
    can :create, MatchContribution

    can :read, Expense
    can :read, Update

    can :read, Contribution, :user_id => user.id

    can :read, Need, :is_public => true
    can :create, User
    can :update, User, :id => user.id
    can :read, User
    can :create_charge, Need

    can :read, Skill

    can :new, TimeContribution
    can :create, TimeContribution, :user_id => user.id
    can :update, TimeContribution, :user_id => user.id
    can :show, TimeContribution, :user_id => user.id
    can :read, TimeContribution, :user_id => user.id

    can :read, Initiative
    can :read, InitiativeMetric

    can :read, Demographic

    # can :read, About // was causing crashing, strange.
    
    # can :manage, :all
    
    # def initialize(user)
    #     # Define abilities for the passed in user here.
    #     user ||= User.new # guest user (not logged in)
    #     # a signed-in user can do everything
    #     if user.has_role? :admin
    #      # an admin can do everything
    #       can :manage, :all
    #     elsif user.has_role? :editor
    #       # an editor can do everything to documents and reports
    #       can :manage, [Document, Report]
    #       # but can only read, create and update charts (ie they cannot
    #       # be destroyed or have any other actions from the charts_controller.rb
    #       # executed)
    #       can [:read, :create, :update], Chart
    #       # an editor can only view the annual report
    #       can :read, AnnualReport
    #     elsif user.has_role? :guest
    #       can :read, [Document, Report, Chart]
    #     end
    # end


    # Define abilities for the passed in user here. For example:
    #
    #   user ||= User.new # guest user (not logged in)
    #   if user.admin?
    #     can :manage, :all
    #   else
    #     can :read, :all
    #   end
    #
    # The first argument to `can` is the action you are giving the user 
    # permission to do.
    # If you pass :manage it will apply to every action. Other common actions
    # here are :read, :create, :update and :destroy.
    #
    # The second argument is the resource the user can perform the action on. 
    # If you pass :all it will apply to every resource. Otherwise pass a Ruby
    # class of the resource.
    #
    # The third argument is an optional hash of conditions to further filter the
    # objects.
    # For example, here the user can only update published articles.
    #
    #   can :update, Article, :published => true
    #
    # See the wiki for details:
    # https://github.com/ryanb/cancan/wiki/Defining-Abilities
  end
end
