class Result < Base
  custom_endpoint :failed_questions, on: :member, request_method: :post
  custom_endpoint :value, on: :member, request_method: :post
  custom_endpoint :current_value, on: :member, request_method: :post
  custom_endpoint :update_value, on: :member, request_method: :put
  custom_endpoint :fp, on: :member, request_method: :post
  custom_endpoint :count_txt, on: :member, request_method: :post
  custom_endpoint :count, on: :member, request_method: :post
  custom_endpoint :count_avg_stddev, on: :member, request_method: :post
  custom_endpoint :update_txt, on: :member, request_method: :put
  custom_endpoint :find_tutor, on: :member, request_method: :post
end
