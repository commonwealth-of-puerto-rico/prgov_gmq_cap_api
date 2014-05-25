# RESTful API for interacting with the Government Message Queue (GMQ) of PR.Gov
# Some code and ideas recycled with permission from:
# github.com/mindware/Automata
# CAP API 2014 (c) Office of the CIO of Puerto Rico
# Developed by: Andrés Colón Pérez for Office of the CIO
# For: Estado Libre Asociado de Puerto Rico

# Load our external libraries
require 'redis/connection/synchrony'
require 'redis'
require 'json'

# Load our Settings and Helper Methods:
require './app/helpers/library'
require './app/helpers/storage'
require './app/helpers/config'
require './app/helpers/authentication'
require './app/helpers/errors'
# Load our Models. Models contain information stored in an Object:
require './app/models/transaction'
require './app/models/user'
# Load our Entities. Grape-Entities are API representations of a Model:
require './app/entities/transaction'

module PRGMQ
	module CAP
		class API < Grape::API

			version 'v1'
			format :json

			# Our middleware to trap exception and return json gracefully.
			use ApiErrorHandler

			# Our helpers
			helpers do
				include PRGMQ::CAP::LibraryHelper	# General Helper Methods
				include PRGMQ::CAP::StorageHelper  # Storage Helper Methods
			end

			http_basic do |username, password|
			  # verify user's password here
			  Authentication.valid?(username, password)
			end


			before do
				# If the system is set up for downtime/maintenance:
				if(Config.downtime)
					# get the path:
			  	path = route.route_path.gsub("/:version/cap", "")
					# Only admin resources are allowed during maintenance mode.
					# Throw an error if this isn't an admin path.
					if !path.start_with?("/admin/")
						# Let the users know this system is down for maintenance:
			  		raise ServiceUnavailable
					end
				end
			end

			# From here on the user is authenticated. Any checks should be for
			# specific access.

			## Resource cap:
			## All the request below require a /v1/ before the resource, ie:
			## GET /v1/cap/...
			resources :cap do
				desc "Returns current version and status information. This is "+
						 "mainly used to test credentials and in the future could be used "+
						 "to see health information."
				# Get cap/
				get '/' do
					# specify a list of user groups than can access this resource
					# validate if this user belongs to the alllowed groups,
					# if it does, get the User Object, else: we'll safely error out.
					user = allowed?(["all"])
					# logger.info "#{user} requested #{route.route_params[params]}"
					{ :api	=> "CAP", :versions => "#{API::versions}" }
				end # end of get '/'

				## Resource cap/transaction:
				group :transaction do

						## Resource cap/transaction/status:
						group :status do
							# GET cap/transaction/status/:status:
							desc "Returns an estimated number of existing transactions in "+
									 "the CAP Transaction system that match a specific status."
							params do
								requires :status, type: String, desc: "A valid status id."
							end
							get "/" do
								user = allowed?(["all"])
										{
									     :transactions =>
											 {
					                :status =>
													{
			                      	:status => "20"
						              }
									     }
										}
							end
						end

						## Resource cap/transaction/:id:
						desc "Returns all available information on a specific "+
								 "transaction id."
						params do
							requires :id, type: String, desc: "A valid transaction id."
						end
						namespace ":id" do
							# Resource cap/transaction/:id/status:
							group :status do
								# GET cap/transaction/:id/status/
								desc "Returns relevant status information on a specific "+
										 "transaction id."
								get "/" do
										# so long as we only return general status info, we can
										# leave this open to all systems. If we start providing
										# specific user information, then only admin and workers.
										user = allowed?(["all"])
										{
										    "transaction" => {
										        "id" => "0-123-456",
										        "current_error_count" => 0,
										        "total_error_count" => 1,
										        "action" => {
										             "id" => 10,
										             "description" => "sending certificate via email"
										         },
										        "status" => "processing",
										        "location" => "prgmq_email_certificate_queue",
										    }
										}
								end
							end

							# GET /v1/cap/transaction/:id/
							desc "Returns all available information on a specific "+
									 "transaction id."
							params do
								optional :id, type: String, desc: "A valid transaction id."
							end
							get do
									user = allowed?(["admin", "worker"])
									if(Transaction.read(params[:id]))
										@transaction = Transaction.new(:id => "1", :name => "hero")
										present @transaction, with: CAP::Entities::Transaction #, type: :hi
									else
										#api_error(InvalidTransactionId)
										raise InvalidTransactionId
									end
							end

							# DELETE /v1/cap/transaction/:id
							desc "Deletes a specific transaction id so it cannot be processed. "+
									"This will likely move the transaction to an alternative "+
									"repository in the future, in order to archive it. This is "+
									"mainly to be used by workers, or for administrative purposes"+
									" such as when duplicates are detected."
							params do
								requires :id, type: String, desc: "A valid transaction id."
							end
							delete do
								user = allowed?(["admin", "worker"])
								{
										"0-123-456" => "deleted"
								}
							end # end of DELETE
						end # end of namespace: Resource cap/transaction/:id:

						# GET /v1/cap/transaction/
						desc "Returns an estimated number of existing transactions in "+
								"the CAP Transaction system."
						get '/' do
							user = allowed?(["all"])
							{
								"transactions" =>
								{
										"pending" => "20",
										"completed" => "100",
										"failed" => "1",
										"retry" => "2",
										"processing" => "5",
								}
							}
						end

						# POST /v1/cap/transaction/
						desc "Request to generate a new transaction, which involves "+
								 "attempting to enqueue the request with a unique transaction "+
								 "id and returning said id."
						params do
							requires :payload, type: String, desc: "A valid transaction payload."
						end
						post '/' do
							allowed_groups = ["admin", "webapp"]
							{
							    "transaction" =>
									{
							        "id" => "0-123-456",
							        "action" => {
							            "id" => 1,
							            "description" => "validating identity and rapsheet with DTOP & SIJC"
							         },
							        "status" => "pending",
							        "location" => "prgmq_validate_rapsheet_with_sijc_queue",
							    }
							}
						end

						# PUT /v1/cap/transaction/
						desc "Requests that the server update information for a given id. "+
								 "This is used to update the current state of a transaction, "+
								 "such as its current location in the message queue or an "+
								 "external system. It may also be used to fix the email for "+
								 "a certain transaction. The transaction id can not be changed."
						params do
							# Remove the following and add actual parameters later.
							requires :payload, type: String, desc: "A valid transaction payload."
						end
						post '/' do
							user = allowed?(["admin", "worker"])
							{
								    "transaction"=> {
								        "id" => "0-123-456",
								        "current_error_count" => 0,
								        "total_error_count" => 1,
								        "action" => {
								            "id" => 10,
								            "description" => "sending certificate via email"
								         },
								        "email" => "levipr@gmail.com",
								        "history" => {
								           "created_at"  => "5/10/2014 2=>30=>00AM",
								           "updated_at" => "5/10/2014 2=>36=>53AM",
								           "updates" => {
								             "5/10/2014 2=>31=>00AM" => "Updating email per user request=> (params=> ‘email’ => ‘levipr@gmail.com’) ",
								           },
								           "failed" => {
								                 "5/10/2014 2=>36=>52AM" => {
								                        "sijc_rci_validate_dtop" => {
								                                     "http_code" =>  502,
								                                     "app_code" =>  8001,
								                         },
								                  },
								            },
												 },
								         "status" => "processing",
								         "location" => "prgmq_email_certificate_queue",
								    }
								}
						end


						# PUT /v1/cap/transaction/certificate_ready
						desc "Requests that the server save the enclosed base64 "+
								 "certificate with the transaction and enqueue a job for "+
								 "processing it by emailing it to the proper email address. "
						params do
							# Remove the following and add actual parameters later.
							requires :payload, type: String, desc: "A valid transaction "+
																										 "payload."
						end
						post '/' do
							user = allowed?(["admin", "worker"])
							{
										"transaction"=> {
												"id" => "0-123-456",
												"current_error_count" => 0,
												"total_error_count" => 1,
												"action" => {
														"id" => 10,
														"description" => "sending certificate via email"
												},
												"email" => "levipr@gmail.com",
												"history" => {
													"created_at"  => "5/10/2014 2=>30=>00AM",
													"updated_at" => "5/10/2014 2=>36=>53AM",
													"updates" => {
														"5/10/2014 2=>31=>00AM" => "Updating email per "+
													  "user request=> (params=> ‘email’ => "+
														"'levipr@gmail.com') ",
													},
													"failed" => {
																"5/10/2014 2=>36=>52AM" => {
																				"sijc_rci_validate_dtop" => {
																										"http_code" =>  502,
																										"app_code" =>  8001,
																				},
																	},
														},
												},
												"status" => "processing",
												"location" => "prgmq_email_certificate_queue",
										}
								}
						end
				end # end of group: Resource cap/transaction:

				group :admin do
					# This resource is here for testing things. It's our own special lab.
					# Get cap/test
					get '/test' do
						# only allowed if we're in development or testing. Disabled on production.
						if(Goliath.env.to_s == "development" or Goliath.env.to_s.include? == "test")
							# specify a list of user groups than can access this resource:
							user = allowed?(["admin"])
							{ :test_data =>  redis.get("mkey")}
						else
							raise ResourceNotFound
						end
					end # end of get '/test'


					# This resource is here for testing things. It's our own special lab.
					# Get cap/maintenance
					desc "Actives or deactives the system maintenance mode."
					params do
						optional :activate, type: Boolean, desc: "A boolean value that "+
																		"determines if we're down for maintenance."
					end
					get '/maintenance' do
						user = allowed?(["admin"])
						return {"maintenance_status" => Config.downtime } if params[:activate].nil?
						Config.downtime = params[:activate]
						{ "maintenance_status" => Config.downtime}
					end # end of get '/maintenance'

					# This resource is here for admins.
					get '/users' do
						user = allowed?(["admin"])
						{ :users => user_list }
					end # end of get '/test'

					# Prints available admin routes. Hard-coded
					# Let's later do some meta-programming and catch these.
					get '/' do
						{
							"available_routes" => ["maintenance", "test", "users"]
						}
					end
				end # end of the administrator group
			end

			# consider adding a self documenting route, that simply lists all
			# routes, their descriptions and their parameters. Similar to:
			# http://code.dblock.org/grape-describing-and-documenting-an-api

			# Trap all errors, return proper 404:
			# This must always be the bottom route, nothing must be below it,
			# this is a catch all to return proper 404 errors.
			route :any, '*path' do
			  raise ResourceNotFound
			end

		end # end of API class
	end # end of CAP module
end # end of GMQ module
