class TestWorker 
	include Sidekiq::Worker
	include Selenium

	# Importing all methods
	require_relative 'methods'
	

	# Sidekiq options
	sidekiq_options :retry => false
	Sidekiq.configure_server do |config|
		database_url = ENV['DATABASE_URL']
		if database_url
			ENV['DATABASE_URL'] = "#{database_url}?pool=25"
			ActiveRecord::Base.establish_connection
		end
	end
	########################################

	# This method performs the test execution asynchronously
	def perform(test_id, user_id)
		
		test = Test.find(test_id)
		
		user = User.find(user_id)
		
		param_url = SeleniumConfig.find_by_user_id(user.id).url.to_sym
		
		run_status = execute_test(user,param_url,test)

		logger.info("\nFinal Status: " + run_status.to_s)
		
		test.update_attributes(status: run_status, last_run: DateTime.now)

		execution = ExecProgress.where(user_id: user.id, test_id: test.id).first
		
		if execution.queue_id

			QueueCart.delete(execution.queue_id)

			qid = execution.queue_id

			ExecProgress.delete(execution.id)

			EM.run {
				client = Faye::Client.new('http://192.168.10.54:9292/faye')
				publication = client.publish("/users/#{user.id}", "
					$('#notification').replaceWith('<a id=\"notification\" href=\"#\" data-toggle=\"tooltip\" title=\"Job Completed\"><i class=\"icon-globe\"></i></a>');
					$('#notification').css(\"background-color\", \"#8A0707\");
					$('#status').replaceWith('<a id=\"status\" href=\"#\" data-toggle=\"tooltip\" title=\"No Jobs in Progress\"><i class=\"icon-bell\"></i></a>');
					$('#q_row_#{qid}').remove();
					")

				publication.callback do
					logger.info("Message sent to channel '/users/#{user.id}'")
				end

				publication.errback do |error|
					logger.info('There was a problem: ' + error.message)
				end
			}
		else

			ExecProgress.delete(execution.id)

			EM.run {
				client = Faye::Client.new('http://192.168.10.54:9292/faye')
				publication = client.publish("/users/#{user.id}", "
					$('#notification').replaceWith('<a id=\"notification\" href=\"#\" data-toggle=\"tooltip\" title=\"Job Completed\"><i class=\"icon-globe\"></i></a>');
					$('#notification').css(\"background-color\", \"#8A0707\");
					$('#status').replaceWith('<a id=\"status\" href=\"#\" data-toggle=\"tooltip\" title=\"No Jobs in Progress\"><i class=\"icon-bell\"></i></a>');
					$('#exec_#{test.id}').replaceWith(\'<a id=\"exec_#{test.id}\" href=\"/exec_test?test_id=#{test.id}\" data-remote=\"true\" class=\"btn btn-small icon-wrench\"></a>\');
					")

				publication.callback do
					logger.info("Message sent to channel '/users/#{user.id}'")
				end

				publication.errback do |error|
					logger.info('There was a problem: ' + error.message)
				end
			}
		
		end
	end
	########################################

	# This method performs the selenium test execution
	def execute_test(user,url,test)

		method = Methods.new
		
		logger.info("Inside execute test")
		
		method.initialize_driver(url)
		
		test_steps = TestStep.where(test_id: test.id)
		
		log=""
		
		run_status=""
		
		execution_name = DateTime.now.strftime('%d%m%Y_%H%M%S')

		test_steps.each do |ts|
			execution = Execution.new(:name => execution_name, :user_id => user.id, :test_suite_id => test.test_suite_id, :test_id => test.id, :test_step_id => ts.id)
			if ts.element_id
				web_element = WebElement.find(ts.element_id)
				log, run_status = method.execute_test_step(web_element,ts.function,ts.value)
				logger.info("\nTest Step: '" + ts.step_name.to_s + "' : " + run_status.to_s)
			else
				log, run_status = method.assert(ts.expected)
				logger.info("\nTest Step: '" + ts.step_name.to_s + "' : " + run_status.to_s)
			end
			ts.update_attributes(status: run_status, last_run: DateTime.now)
			execution.status = run_status
			execution.last_run = DateTime.now
			execution.save
		end
		
		method.close

		return run_status
	end
	########################################

end