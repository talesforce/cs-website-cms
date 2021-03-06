require 'will_paginate/array'

class AccountsController < ApplicationController
  before_filter :authenticate_user!

  def update
    account_attrs = params[:account].dup
    account_attrs.delete("years_of_experience") if account_attrs[:years_of_experience].blank?

    if params[:profile_picture]
      resp = Cloudinary::Uploader.upload(params[:profile_picture], :public_id => current_user.username)
      account_attrs["profile_pic"] = Cloudinary::Utils.cloudinary_url "#{resp["public_id"]}.#{resp["format"]}", width: 125, height: 125, crop: "fill"
    end

    response = Member.http_put("members/#{current_user.username}", account_attrs)
    if response.success == "false"
      flash[:error] = "Failed to update, reason : #{response.message}"
    else
      flash[:notice] = "Updated successfully"
    end
    
    redirect_to :back
  end

  def details
    fields = 'id,name,profile_pic,first_name,last_name,email,address_line1,address_line2,city,zip,state,phone_mobile,time_zone,country'
    @member = Member.find(current_user.username, fields: fields)
  end

  def payment_info
    fields = 'id,name,preferred_payment,paperwork_received,paperwork_sent,paperwork_year,paypal_payment_address'
    @member = Member.find(current_user.username, fields: fields)

    @payments = @member.payments
    @paid_payments = @payments.select(&:paid?)
    @outstanding_payments = @payments - @paid_payments
    respond_to do |format|
      format.html
      format.json { render :json => {:outstanding => @outstanding_payments, 
      :paid => @paid_payments } }
    end     
  end

  def school_and_work
    fields = 'id,name,company,school,years_of_experience,work_status,shirt_size,age_range,gender'
    @member = Member.find(current_user.username, fields: fields)
  end

  def public_profile
    fields = 'id,name,profile_pic,summary_bio,quote,website,twitter,github,facebook,linkedin'
    @member = Member.find(current_user.username, fields: fields)
	end

  def change_password
    @login_type = Member.login_type(current_user.username)
  end

  def challenges
    member = Member.find current_user.username
    all_challenges = member.all_challenges
    @followed_challenges = member.watching_challenges(all_challenges)
    @active_challenges   = member.active_challenges(all_challenges)
    @past_challenges     = member.past_challenges(all_challenges)

    respond_to do |format|
      format.html
      format.json { render :json => {:active => @active_challenges, 
      :past => @past_challenges, :watching => @followed_challenges } }
    end        
  end

  def past_challenges
    member = Member.find current_user.username
    page = params[:page] || 1
    offset = (page.to_i * 10) - 10
    all_challenges  = member.all_past_challenges(offset)
    @past_challenges = all_challenges.records.map {|challenge| Challenge.new challenge}
    # fake the pagination
    @pagination = []
    (1..all_challenges.total).each { |x| @pagination << x }
    @pagination = @pagination.paginate(:page => params[:page], :per_page => 10)
  end  

  def communities
    @communities = Community.all
  end

  def referred_members
    @member = Member.find(current_user.username)		
    @referrals = @member.referrals
  end

  def invite_friends
    if request.post?
      params[:emails].each {|email| Resque.enqueue(InviteEmailSender, current_user.username, current_user.profile_pic, email)}
      flash.now[:notice] = 'Your invites have been sent!'
    end		
  end

  end
