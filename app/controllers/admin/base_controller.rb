# ฐานของทุก controller ฝั่ง admin: เฉพาะ role admin (AUTH-10, NFR-08)
class Admin::BaseController < ApplicationController
  allow_roles :admin
end
