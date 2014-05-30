class Contribution < ActiveRecord::Base
  belongs_to :need
  belongs_to :user
  belongs_to :contributor

  monetize :amount_cents

  attr_writer :stripe_token
  attr_writer :stripe_currency

  before_create :assign_to_user_or_contributor

  # Switched these to only if the contribution succeeds.
  # after_create :mail_to_church_admin
  # after_create :mail_to_user_posted_by
  # after_create :mail_to_users_who_contributed_if_fully_funded
  # after_create :mail_receipt

  scope :succeded, -> { where(succeded: true) }
  scope :not_reimbursed, -> { where(reimbursed: false) }

  def mail_to_church_admin
    # should this be async?
    Mailer.church_admin_need_recieved_contribution(self.need.user_church_admin.id, self.need.id, self.id).deliver
  end

  def mail_to_user_posted_by
    # should this be async?
    Mailer.user_posted_by_need_recieved_contribution(self.need.user_posted_by.id, self.need.id, self.id).deliver
  end

  def mail_to_need_leader_if_exists
    # should this be async?
    if self.need.user_need_leader
      Mailer.need_leader_need_recieved_contribution(self.need.user_need_leader.id, self.need.id, self.id).deliver
    end
  end


  def mail_receipt
    # should this be async?
    if self.user
      Mailer.receipt_to_user(self.user.id, self.need.id, self.id).deliver
    elsif self.contributor
      Mailer.receipt_to_contributor(self.contributor.id, self.need.id, self.id).deliver
    end
  end

  # Probably don't want these, just so there is no way money gets lost
  #validates :need, presence: true
  #validates :contributor, presence: true

  def process_payment

# emailAddress = "nil"
# if defined? email
#   emailAddress = email
# end

    charge = Stripe::Charge.create(amount: amount_cents,
                                   currency: @stripe_currency,
                                   card: @stripe_token,
                                   description: "#{Rails.env} - contribution_id:#{id} need_id:#{need.id} email:#{email} title:#{need.title}")
  self.update_column(:succeded, true)
  self.update_column(:reimbursed, false)
  mail_to_church_admin
  mail_to_need_leader_if_exists
  mail_to_user_posted_by
  mail_to_users_who_contributed_if_fully_funded
  mail_receipt
  true
  rescue Stripe::CardError
    self.update_column(:succeded, false)
    self.update_column(:reimbursed, false)
    false
  end

  private

  def assign_to_user_or_contributor
    self.user ||= User.find_by_email(email)
    if user
      self.email ||= user.email
      # Would be great to have this here but it was causing an infinite loop.
                                                      
      # Activity.create(
      #   subject: self,
      #   description: 'User made contribution.',
      #   user: self.user
      # )
    else
      self.contributor = Contributor.where(email: email).first_or_create
      # Would be great to have this here but it was causing an infinite loop.

      # Activity.create(
      #   subject: self,
      #   description: 'Contributor made contribution.',
      #   user: self.user
      # )
    end
  end

  def mail_to_users_who_contributed_if_fully_funded
    if self.need.percent_raised >= 100.0
      if self.need.total_expenses > Money.new(0, "USD")
        # Alert the church admin
        past_relevant_activities = Activity.where(user_id: self.need.user_church_admin.id, subject: self.need, description: 'Mailed news that need is fully funded to Church Admin.')
        if past_relevant_activities.count == 0
          # Only email the user if they haven't been emailed about it yet.
          Mailer.church_admin_need_fully_funded(self.need.user_church_admin.id, self.need.id).deliver
          Activity.create(
            subject: self.need,
            description: 'Mailed news that need is fully funded to Church Admin.',
            user: self.need.user_church_admin
          )
        end
        # Alert the need poster
        past_relevant_activities = Activity.where(user_id: self.need.user_posted_by.id, subject: self.need, description: 'Mailed news that need is fully funded to Need Poster.')
        if past_relevant_activities.count == 0
          # Only email the user if they haven't been emailed about it yet.
          Mailer.user_posted_by_need_fully_funded(self.need.user_posted_by.id, self.need.id).deliver
          Activity.create(
            subject: self.need,
            description: 'Mailed news that need is fully funded to Need Poster.',
            user: self.need.user_posted_by
          )
        end
        # Alert the need leader if exists

        if self.need.user_need_leader
          past_relevant_activities = Activity.where(user_id: self.need.user_need_leader.id, subject: self.need, description: 'Mailed news that need is fully funded to Need Leader.')
          if past_relevant_activities.count == 0
            # Only email the user if they haven't been emailed about it yet.
            Mailer.need_leader_need_fully_funded(self.need.user_need_leader.id, self.need.id).deliver
            Activity.create(
              subject: self.need,
              description: 'Mailed news that need is fully funded to Need Leader.',
              user: self.need.user_need_leader
            )
          end
        end 

        # Alert the contributors (with/without accounts)
        self.need.contributions.succeded.not_reimbursed.each do |contribution|
          if contribution.user
            past_relevant_activities = Activity.where(user_id: contribution.user.id, subject: self.need, description: 'Mailed news that need is fully funded to contributor (with account).')
            if past_relevant_activities.count == 0
              # Only email the user if they haven't been emailed about it yet.
              Mailer.user_need_contributed_to_fully_funded(contribution.user.id, self.need.id).deliver
              Activity.create(
                subject: self.need,
                description: 'Mailed news that need is fully funded to contributor (with account).',
                user: contribution.user
              )
            end
          elsif contribution.contributor
            past_relevant_activities = Activity.where(user_id: nil, subject: self.need, description: 'Mailed news that need is fully funded to contributor (without account - #{contribution.contributor.email}).')
            if past_relevant_activities.count == 0
              # Only email the user if they haven't been emailed about it yet.
              Mailer.contributor_need_contributed_to_fully_funded(contribution.contributor.id, self.need.id).deliver
              Activity.create(
                subject: self.need,
                description: 'Mailed news that need is fully funded to contributor (without account - #{contribution.contributor.email}).',
                user: nil
              )
            end
          end
        end
        # Alert the volunteers
        self.need.time_contributions.each do |time_contribution|
          if time_contribution.user
            past_relevant_activities = Activity.where(user_id: time_contribution.user.id, subject: self.need, description: 'Mailed news that need is fully funded to volunteer.')
            if past_relevant_activities.count == 0
              # Only email the user if they haven't been emailed about it yet.
              Mailer.volunteer_need_volunteered_for_fully_funded(time_contribution.user.id, self.need.id).deliver
              Activity.create(
                subject: self.need,
                description: 'Mailed news that need is fully funded to volunteer.',
                user: time_contribution.user
              )
            end
          end
        end
      end
    end
  end
end
