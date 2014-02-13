class QueueCartController < ApplicationController
    before_action :signed_in_user
    
    def show_pending
        @user_id = current_user.id
        @jobs = Job.where(user_id: @user_id, status: "Pending").to_a
        respond_to do |wants|
            wants.html {  }
            wants.js { render 'queue_cart/show_pending.js.haml' }
        end
    end

    def show_processed
        respond_to do |wants|
            wants.html {  }
            wants.js { }
        end
    end

    def reports
       # To do
    end

    def show_report
        # To do
    end

    def delete_report
       # To do
    end

    def view_error
        # To Do
    end

    def execute
        @user_id = current_user.id
        if params[:commit]=="Execute Selected" then
            @job_ids = params[:job_id]
            @job_ids.each do |id|
                @job = Job.find(id)
                @job.update_attributes(status: 'Started')
                if @job.test_step_id
                    #TestStepWorker.perform_async(@job.test_step_id,@user_id)
                else
                    TestWorker.perform_async(@job.id)
                end
            end
        else
            @job_ids = Array.new
            @jobs = Job.where(user_id: @user_id, status: 'Pending').to_a
            @jobs.each do |job|
                @job_ids.push job.id
                job.update_attributes(status: 'Started')
                if job.test_step_id
                    #TestStepWorker.perform_async(job.test_step_id,@user_id)
                else
                    TestWorker.perform_async(job.id)
                end
            end
        end
        respond_to do |wants|
            wants.js { }
        end
    end

    def destroy
        @job_id = params[:id]
        if Job.find(params[:id]).delete
            flash.now[:success] = "Job removed from queue!"
        else
            flash.now[:error] = "Unexpected error occurred!"
        end
        respond_to do |wants|
            wants.js { }
        end
    end

    def destroy_all
        @user_id = current_user.id
        @jobs = Job.where(user_id: @user_id).to_a
        Job.delete_all(user_id: @user_id)
        flash.now[:success] = "All Jobs removed from queue!"
        respond_to do |wants|
            wants.js { }
        end
    end

    private
        def signed_in_user
            redirect_to root_url, notice:"Please Sign In" unless signed_in?
        end
        def post_params
            params.require(:queue_cart).permit(:test_suite_id,:test_step_id,:test_id)
        end
end
